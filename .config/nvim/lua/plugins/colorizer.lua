return {
	"catgoose/nvim-colorizer.lua",
	event = "BufReadPre",
	opts = {
		user_default_options = {
			names = false, -- don't highlight color words like "blue"
			RGB = true, -- #RGB
			RRGGBB = true, -- #RRGGBB
			RRGGBBAA = true, -- #RRGGBBAA
			rgb_fn = true, -- rgb() / rgba()
			hsl_fn = true, -- hsl() / hsla()
			css = true, -- enable all css features
			mode = "background", -- show color as the background of the hex value
		},
	},
}
