import os
from PIL import Image

folder = r"d:\gestionCamion\fleetguard\assets\images\markers"

def process_image(filepath):
    img = Image.open(filepath).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    for item in data:
        # The fake checkerboard usually consists of perfectly alternating white and gray squares
        # Let's remove any pixel that matches exactly (255, 255, 255) OR (204, 204, 204)
        # Note: this might remove white reflections on the truck. 
        # A safer way: Flood fill from the corners!
        pass
        
    # Better method: Flood fill
    from PIL import ImageDraw
    # Convert to RGB to do flood fill (flood fill with transparency targets can be tricky)
    rgb_img = img.convert("RGBA")
    
    # We will just make a mask of the background.
    # The checkerboard is mostly (255,255,255) or (204,204,204).
    # Since flood fill requires a single solid color, we can't easily flood-fill a checkerboard.
    # INSTEAD, let's just make both (255,255,255) and (204,204,204) transparent if they are in the image.
    width, height = img.size
    pixels = img.load()
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # typical checkerboard grey
            if (r > 195 and r < 210 and g > 195 and g < 210 and b > 195 and b < 210) or \
               (r > 250 and g > 250 and b > 250):
                # Only remove if it's near the edges? No, let's just remove all perfect whites and greys.
                # Actually, the user's screenshot has literal checkerboard squares all over.
                pixels[x, y] = (255, 255, 255, 0)

    img.save(filepath.replace(".png", "_cleaned.png"))
    print(f"Cleaned {filepath}")

for f in os.listdir(folder):
    if f.endswith(".png") and not f.endswith("_cleaned.png"):
        process_image(os.path.join(folder, f))
