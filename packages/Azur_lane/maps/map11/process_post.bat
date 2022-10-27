rem you need ImageMagick convert.exe	

rem 1-pass terrain optimization: merge splat files to one, 4 is max

convert terrain5_alpha_grass.png -colorspace RGB terrain5_alpha_wheat.png -colorspace RGB terrain5_alpha_burned_ground.png -colorspace RGB terrain5_alpha_road.png -colorspace RGB  -channel RGBA -combine terrain5_combined_alpha.png

convert effect_none.png -colorspace RGB effect_none.png -colorspace RGB effect_none.png -colorspace RGB effect_alpha_blood.png -colorspace RGB -channel RGBA -combine -colorspace RGB PNG32:effect_combined_alpha.png