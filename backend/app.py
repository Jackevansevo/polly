import asyncio
import json
import os
import sys
from collections import defaultdict
from http import HTTPStatus
from itertools import repeat
from json.decoder import JSONDecodeError
from uuid import UUID, uuid4

import httpx
import typesystem
import uvicorn
from starlette.applications import Starlette
from starlette.middleware.cors import CORSMiddleware
from starlette.responses import Response, UJSONResponse
from starlette_prometheus import PrometheusMiddleware, metrics
from walrus import Database

from poll import Poll, RecaptchaResponse

# [TODO] Eval the use of pipelines and transactions
DEBUG = os.environ.get("DEBUG", False)
SECRET_KEY = os.environ.get("SECRET_KEY")
CAPTCHA_URL = "https://www.google.com/recaptcha/api/siteverify"

if SECRET_KEY is None:
    sys.exit("SECRET_KEY not set")


app = Starlette(debug=DEBUG)

db = Database()
# [TODO] Figure out why this doesn't work inside a docker container
# rate_limit = db.rate_limit("mylimit", limit=2, per=60)

app.add_middleware(PrometheusMiddleware)
app.add_route("/metrics", metrics)
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


@app.on_event("startup")
async def open_database_connection_pool():
    global db
    # Load hostname from environment variable, fallback to host if not set
    host = os.environ.get("HOST", "localhost")
    # Attempt to establish a database connection
    db = Database(host=host, port=6379)


async def verify_request(request, token):
    async with httpx.AsyncClient() as client:
        data = {
            "secret": SECRET_KEY,
            "response": token,
            "remoteip": request.client.host,
        }
        r = await client.post(CAPTCHA_URL, data=data)
        body = r.json()
        api_response = RecaptchaResponse.validate(body)
        return body.get("success", False) and body.get("score", 0) >= 0.7


@app.route("/", methods=["POST"])
async def create(request):
    """Creates a new poll"""

    # [TODO] Check if user has been rate limited or not

    # if rate_limit.limit(request.client.host):
    #     return Response(
    #         f"you're doing that too often", status_code=HTTPStatus.TOO_MANY_REQUESTS
    #     )

    try:
        body = await request.json()
    except JSONDecodeError as error:
        return Response(
            f"failed to decode JSON: {error}", status_code=HTTPStatus.BAD_REQUEST
        )

    if (token := body.get("token")) is None:
        return Response(f"missing recaptcha token", status_code=HTTPStatus.BAD_REQUEST)

    success = await verify_request(request, token)
    if not success:
        return Response(f"failed recaptcha", status_code=HTTPStatus.BAD_REQUEST)

    try:
        poll = Poll.validate(body)
    except typesystem.ValidationError as error:
        print(error)
        return Response(
            str(error),
            status_code=HTTPStatus.BAD_REQUEST,
            media_type="application/json",
        )

    # The unique key used to identify each quiz
    pid = uuid4()
    poll.creator = request.client.host

    db.set(pid.hex, json.dumps(dict(poll)))
    db.hmset(f"{pid.hex}:votes", dict(zip(poll.options, repeat(0))))
    return UJSONResponse({"pid": pid.hex})


@app.route("/", methods=["DELETE"])
async def delete(request):
    pid = UUID(request.query_params["pid"])
    db.delete(pid.hex, f"{pid.hex}:votes", f"{pid.hex}:ips")
    return Response(status_code=HTTPStatus.OK)


@app.route("/vote", methods=["POST"])
async def vote(request):
    """Casts a vote in the quiz"""

    try:
        body = await request.json()
    except JSONDecodeError as error:
        return Response(
            f"failed to decode JSON: {error}", status_code=HTTPStatus.BAD_REQUEST
        )

    if (token := body.get("token")) is None:
        return Response(f"missing recaptcha token", status_code=HTTPStatus.BAD_REQUEST)

    success = await verify_request(request, token)
    if not success:
        return Response(f"failed recaptcha", status_code=HTTPStatus.BAD_REQUEST)


    pid_param = request.query_params.get("pid")

    if pid_param is None:
        return Response("Error: missing pid", status_code=HTTPStatus.BAD_REQUEST)

    try:
        pid = UUID(pid_param)
    except ValueError as error:
        return Response(f"Invlaid pid: {pid_param}", status_code=HTTPStatus.BAD_REQUEST)

    # Check if the poll exists in the database
    if db.exists(pid.hex) is None:
        return Response(status=404)

    params = defaultdict(list)
    for k, v in request._query_params._list:
        params[k].append(v)

    options = params.get("option")

    if options is None:
        return Response("missing option param", status_code=HTTPStatus.BAD_REQUEST)

    for option in options:
        # Check if the option exists
        if not db.hexists(f"{pid.hex}:votes", option):
            return Response("Invalid option", status_code=HTTPStatus.BAD_REQUEST)

    # Check if the user has already voted
    ip_address = request.client.host
    has_voted = db.sismember(f"{pid.hex}:ips", ip_address)
    if has_voted:
        return Response(
            "Error: you have already voted in this poll",
            status_code=HTTPStatus.METHOD_NOT_ALLOWED,
        )

    for option in options:
        db.hincrby(f"{pid.hex}:votes", option, 1)
        db.sadd(f"{pid.hex}:{ip_address}", option)

    db.sadd(f"{pid.hex}:ips", ip_address)

    return Response(status_code=HTTPStatus.NO_CONTENT)


@app.route("/", methods=["GET"])
async def results(request):
    pid_param = request.query_params.get("pid")
    if pid_param is None:
        return Response("Error: missing pid", status_code=HTTPStatus.BAD_REQUEST)

    try:
        pid = UUID(pid_param)
    except ValueError:
        return Response(f"Invlaid pid: {pid_param}", status_code=HTTPStatus.BAD_REQUEST)

    if not db.exists(pid.hex):
        return Response(status_code=HTTPStatus.NOT_FOUND)

    # Check if the user has already voted
    ip_address = request.client.host

    # Check if the user has voted
    has_voted = db.sismember(f"{pid.hex}:ips", ip_address)

    poll = json.loads(db.get(pid.hex), object_hook=Poll)

    resp = {
        "pid": pid.hex,
        "title": poll.title,
        "options": poll.options,
        "multi": poll.multi,
        "voted": has_voted,
    }

    if has_voted:
        votes = db.hgetall(f"{pid.hex}:votes")
        results = {k: int(v) for k, v in votes.items()}
        resp["results"] = results
        resp["votes"] = db.smembers(f"{pid.hex}:{ip_address}")

    return UJSONResponse(resp)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
