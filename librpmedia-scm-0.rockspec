rockspec_format = "3.0";
package = "LibRPMedia";
version = "scm-0";

description = {
  summary = "LibRPMedia Database Generator",
  license = "Unlicense",
  homepage = "https://github.com/wow-rp-addons/LibRPMedia",
  issues_url = "https://github.com/wow-rp-addons/LibRPMedia/issues",
  maintainer = "me@meorawr.io",
}

source = {
    url = "https://github.com/wow-rp-addons/LibRPMedia",
};

dependencies = {
    "lua = 5.1",
    "lsqlite3",
    "luabitop",
    "luacasc",
    "luafilesystem",
    "luasec",
    "luasocket",
    "lua-zlib",
    "md5",
};

build = {
    type = "none",

    install = {
        bin = {
            ["lrpm-export"] = "Exporter/Export.lua",
        },
    },
};
