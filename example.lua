vim.api.nvim_set_hl(0, "NvimFishShiny", { fg = "#FFFD00", bold = true })
require("nvim-fish").setup({
			species = {
				fish = { max = 4 },
				tuna = {
					max = 2,
					spawn_chance = 0.05,
					sprites = {
						right = [[\
\/\
/\/
 /]],
						left = [[/
/\/
\/\
 \]],
					},
					behaviour = {
						"target",
						pattern = "%d+",
					},
				},
				golden = {
					max = 1,
					spawn_chance = 1 / 65536,
					sprites = {
						right = "><<>",
						left = "<>><",
					},
					behaviour = {
						"sine",
						amplitude = 7,
						period = 10,
					},
					hl_group = "NvimFishShiny",
				},
				gold_seahorse = {
					max = 1,
					spawn_chance = 1 / 2 ^ 20,
					sprites = {
						left = [[:=@
{|<
 |
 J]],
						right = [[@=:
>|}
 |
 J]],
					},
					behaviour = {
						"zigzag",
						amplitude = 9,
					},
					hl_group = "NvimFishShiny",
				},
			},
		})
