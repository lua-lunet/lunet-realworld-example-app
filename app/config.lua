local db_config = require("app.db_config")

return {
    db = db_config,
    server = {
        host = os.getenv("HOST") or "0.0.0.0",
        port = tonumber(os.getenv("PORT")) or 8080,
    },
    jwt_secret = os.getenv("JWT_SECRET") or "change-me-in-production-use-random-32-bytes",
    jwt_expiry = tonumber(os.getenv("JWT_EXPIRY")) or 86400 * 7,
}
