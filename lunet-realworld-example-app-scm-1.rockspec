rockspec_format = "3.0"
package = "lunet-realworld-example-app"
version = "scm-1"

source = {
   url = "git+https://github.com/lua-lunet/lunet-realworld-example-app.git",
   branch = "main"
}

description = {
   summary = "RealWorld example application built with lunet",
   detailed = [[
      A full-featured implementation of the RealWorld spec (https://realworld.io)
      using the lunet async I/O runtime. Implements a Medium.com clone API with:
      - User authentication (JWT)
      - Articles CRUD
      - Comments
      - Favorites
      - User following
      - Tags
   ]],
   homepage = "https://github.com/lua-lunet/lunet-realworld-example-app",
   license = "MIT"
}

dependencies = {
   "lua >= 5.1",
   "lunet >= scm-1",
   "lunet_sqlite >= scm-1"
}

build = {
   type = "builtin",
   modules = {},
   install = {
      lua = {
         ["app.main"] = "app/main.lua",
         ["app.config"] = "app/config.lua",
         ["app.db_config"] = "app/db_config.lua",
         ["app.lib.http"] = "app/lib/http.lua",
         ["app.lib.db"] = "app/lib/db.lua",
         ["app.lib.auth"] = "app/lib/auth.lua",
         ["app.lib.json"] = "app/lib/json.lua",
         ["app.lib.crypto"] = "app/lib/crypto.lua",
         ["app.handlers.users"] = "app/handlers/users.lua",
         ["app.handlers.articles"] = "app/handlers/articles.lua",
         ["app.handlers.comments"] = "app/handlers/comments.lua",
         ["app.handlers.profiles"] = "app/handlers/profiles.lua",
         ["app.handlers.tags"] = "app/handlers/tags.lua",
      }
   },
   copy_directories = {"app"}
}
