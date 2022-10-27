rem you need ImageMagick convert.exe

rem splat files: extract alpha channel, 8-bit greyscale, apply some gaussian blur
convert.exe _rwr_alpha_grass.png -alpha extract -depth 8 -gaussian-blur 2x2 terrain5_alpha_grass.png
convert.exe _rwr_alpha_wheat.png -alpha extract -depth 8 -gaussian-blur 2x2 terrain5_alpha_wheat.png
convert.exe _rwr_alpha_burned_ground.png -alpha extract -depth 8 terrain5_alpha_burned_ground.png
convert.exe _rwr_alpha_road.png -alpha extract -depth 8 -gaussian-blur 2x2 terrain5_alpha_road.png


rem need to negate blood
convert.exe _rwr_alpha_blood.png -alpha extract -depth 8 -gaussian-blur 2x2 -negate effect_alpha_blood.png


rem heightmap to 513x513, 8-bit greyscale
convert.exe _rwr_height.png -type Grayscale -resize 513x513 -depth 8 terrain5_heightmap.png

rem optimize
process_post.bat