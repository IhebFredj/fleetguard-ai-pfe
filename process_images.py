import os
from PIL import Image, ImageDraw

folder = r"d:\gestionCamion\fleetguard\assets\images\markers"

for filename in os.listdir(folder):
    if not (filename.startswith("truck_") and filename.endswith(".png") and not "_fixed" in filename):
        continue
        
    filepath = os.path.join(folder, filename)
    print("Processing", filename)
    try:
        img = Image.open(filepath).convert("RGBA")
        
        # 1. Resize down to 256x256
        img.thumbnail((256, 256), Image.Resampling.LANCZOS)
        
        # 2. Convert to RGBA pixel data
        pixels = img.load()
        width, height = img.size
        
        # 3. Simple greedy algorithm: The fake checkerboard pixels are roughly (R~G~B > 195).
        # We will iterate and set matching pixels to transparent.
        # To avoid erasing the white of the truck cabin too much, we look strictly at the
        # specific grays and whites.
        
        for y in range(height):
            for x in range(width):
                r, g, b, a = pixels[x, y]
                # Light checkerboard
                if r > 190 and r < 210 and g > 190 and g < 210 and b > 190 and b < 210:
                    pixels[x, y] = (0, 0, 0, 0)
                # White checkerboard
                elif r > 240 and g > 240 and b > 240:
                    pixels[x, y] = (0, 0, 0, 0)
                    
        # 4. Save
        new_filename = filename.replace(".png", "_fixed.png")
        img.save(os.path.join(folder, new_filename), "PNG")
        print("Saved", new_filename)
    except Exception as e:
        print("Error on", filename, e)
