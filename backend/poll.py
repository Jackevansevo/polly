import typesystem


class Poll(typesystem.Schema):
    title = typesystem.String(max_length=100)
    options = typesystem.Array(items=typesystem.String(), unique_items=True)
    multi = typesystem.Boolean(default=False)
    suspended = typesystem.Boolean(default=False)
    creator = typesystem.String(allow_null=True)


class RecaptchaResponse(typesystem.Schema):
    success = typesystem.Boolean(default=False)
    challenge_ts = typesystem.String(allow_null=True)
    hostname = typesystem.String(allow_null=True)
    score = typesystem.Float(allow_null=True)
    action = typesystem.String(allow_blank=True)
    error_codes = typesystem.Array(
        title="error-codes", items=typesystem.String(), allow_null=True
    )
