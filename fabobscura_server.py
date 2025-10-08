import argparse
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import os
import numpy as np
import cv2
import imutils
import matplotlib
matplotlib.use('Agg')  # non-interactive backend suitable for scripts and web servers
import matplotlib.pyplot as plt
import re
import io
from PIL import Image, ImageChops
import sympy as sp
from sympy import Piecewise
from urllib.parse import unquote
from flask import Flask, request, jsonify
app = Flask(__name__)

data_folder = "fabobscura_ui/data"

def rotate_image_bound(image, angle):
    return imutils.rotate_bound(image, angle)

def rotate_array_cv2(array, angle):
    (h, w) = array.shape[:2]
    center = (w // 2, h // 2)

    # Compute rotation matrix
    M = cv2.getRotationMatrix2D(center, angle, 1.0)

    # Perform rotation
    rotated = cv2.warpAffine(array, M, (w, h))
    return rotated

def generate_custom_wavy_pattern(height, width, wave_function, line_thickness, n):
    y, x = np.indices((height, width))
    wave = wave_function(x / width)

    spacing = n * line_thickness
    pattern = np.ones((height, width), dtype=np.uint8) * 255

    # Calculate position relative to the wavy line
    relative_pos = (y - wave) % spacing

    # Set pixels to black if they fall within the black_thickness region
    black_thickness = (n - 1) * line_thickness
    pattern[relative_pos >= line_thickness] = 0
    pattern[relative_pos >= (line_thickness + black_thickness)] = 255

    return pattern


def generate_variable_sunburst(wedge_angle_deg, n, wave_function, points_per_line, image_size):
    """
    Generates radial curved sunburst patterns with specified wedge thicknesses:
    - White wedges: wedge_angle_deg
    - Black wedges: (n-1) * wedge_angle_deg

    Parameters:
    - wedge_angle_deg: Angular thickness of white wedges in degrees
    - n: Ratio factor; black wedge is (n-1)*wedge_angle_deg
    """
    r_inner=0.01
    r_outer=1

    wedge_cycle = [wedge_angle_deg/float(n), wedge_angle_deg/float(n) * (n - 1)]  # [white, black]

    total_angle_deg = 360

    radii = np.linspace(r_inner, r_outer, points_per_line)

    # Precompute angles for wedges
    angles = []
    current_angle = 0
    color_cycle = []
    color_flag = True  # Start with white wedge

    while current_angle < total_angle_deg:
        wedge_size = wedge_cycle[0 if color_flag else 1]
        angles.append((current_angle, current_angle + wedge_size))
        color_cycle.append('white' if color_flag else 'black')
        current_angle += wedge_size
        color_flag = not color_flag


    fig = plt.figure(figsize=(image_size / 100, image_size / 100), dpi=100)
    ax = fig.add_axes([0, 0, 1, 1])  # fills the entire figure without padding


    # Function to generate a single radial curve
    def radial_curve(start_angle_deg):
        angles_curve = []
        current_rad_angle = np.radians(start_angle_deg)
        for i in range(len(radii) - 1):
            r = radii[i]
            dr = radii[i + 1] - r
            alpha_deg = wave_function(r)
            alpha_rad = np.radians(alpha_deg)
            # d_beta = (180 / np.pi) * (dr * np.tan(alpha_rad) / r)
            d_beta = (dr * np.tan(alpha_rad) / r)
            # current_rad_angle += np.radians(d_beta)
            current_rad_angle += d_beta
            angles_curve.append(current_rad_angle)
        return np.array(angles_curve)

    # Draw wedges
    for idx, ((start_deg, end_deg), color) in enumerate(zip(angles, color_cycle)):
        angle1 = radial_curve(start_deg)
        angle2 = radial_curve(end_deg)

        x1, y1 = radii[:-1] * np.cos(angle1), radii[:-1] * np.sin(angle1)
        x2, y2 = radii[:-1] * np.cos(angle2), radii[:-1] * np.sin(angle2)

        wedge_x = np.concatenate([x1, x2[::-1]])
        wedge_y = np.concatenate([y1, y2[::-1]])

        ax.fill(wedge_x, wedge_y, color=color, edgecolor='none')

    ax.set_xlim(-1, 1)
    ax.set_ylim(-1, 1)
    ax.set_aspect('equal')
    ax.axis('off')

    plt.axis('off')  # removes axes
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)  # removes margins

    # Save the figure without axes, labels, or extra padding
    
    buf = io.BytesIO()

    plt.savefig(buf, dpi=100, format='png', pad_inches=0)
    buf.seek(0)

    # Load buffer into a PIL Image, then convert to NumPy array
    image = Image.open(buf).convert("L")
    image_array = np.array(image)

    # Close the buffer
    buf.close()
    plt.close()  # optionally close the figure if you don't need to display it

    return image_array

def mask_image(image, pattern):
    """Ensures that the mask has the same size and type before applying it."""
    if len(pattern.shape) == 3:
        pattern = cv2.cvtColor(pattern, cv2.COLOR_BGR2GRAY)  # Convert to single channel if necessary

    pattern = cv2.resize(pattern, (image.shape[1], image.shape[0]), interpolation=cv2.INTER_NEAREST)  # Resize pattern to match
    _, pattern = cv2.threshold(pattern, 128, 255, cv2.THRESH_BINARY)  # Ensure mask is binary
    pattern = pattern.astype(np.uint8)  # Ensure mask is 8-bit

    return cv2.bitwise_and(image, image, mask=pattern)

def bottom_crop(image, crop_width, crop_height):
    """
    Crops the bottom `crop_height` pixels from the image.

    Parameters:
    - image: NumPy array representing the image.
    - crop_height: The number of pixels to keep from the bottom.

    Returns:
    - Cropped image.
    """
    return image[-crop_height:, :crop_width]  # Keeps only the bottom `crop_height` pixels

def center_crop(image, crop_width, crop_height):
    """
    Crops the image to the specified width and height, centered.

    Parameters:
    - image: The input image (NumPy array).
    - crop_width: Desired width of the cropped area.
    - crop_height: Desired height of the cropped area.

    Returns:
    - Cropped image.
    """
    h, w = image.shape[:2]  # Get image dimensions

    # Compute the top-left corner for cropping
    start_x = max((w - crop_width) // 2, 0)
    start_y = max((h - crop_height) // 2, 0)

    # Ensure crop dimensions do not exceed the image size
    end_x = start_x + crop_width
    end_y = start_y + crop_height

    return image[start_y:end_y, start_x:end_x]


# Composite images with rotating sunburst pattern
def composite_images_with_rotating_pattern(images, wedge_angle_deg,
                                           inclination_func,
                                           points_per_line):

    n = len(images)

    # Determine image size based on the first image
    first_img = images[0]
    height, width, alpha = first_img.shape
    image_size = min(height, width)

    # Crop first image to center
    first_img_cropped = center_crop(first_img, image_size, image_size)

    composite = np.zeros((image_size, image_size, alpha), dtype=np.uint8)

    # Generate and rotate pattern
    sunburst_mask = generate_variable_sunburst(
        wedge_angle_deg,
        n,
        inclination_func,
        points_per_line,
        image_size
    )

    rotate_amount = wedge_angle_deg/float(n)
    pattern = sunburst_mask.copy()

    for img in images:
        img = center_crop(img, image_size, image_size)
        masked = mask_image(img, sunburst_mask)
        composite = cv2.addWeighted(composite, 1, masked, 1, 0)
        sunburst_mask = rotate_array_cv2(sunburst_mask, -rotate_amount)
    
    # Increase brightness (optional)
    brightness_factor = 1 + (n - 1) / n
    brightness_factor = 1
    composite = np.clip(composite.astype(np.float32) * brightness_factor, 0, 255).astype(np.uint8)

    # Finalize and save composite image
    # composite = np.clip(composite.astype(np.float32), 0, 255).astype(np.uint8)

    mask = np.zeros((image_size, image_size), dtype=np.uint8)
    cv2.circle(mask, (image_size // 2, image_size // 2), image_size // 2, 255, -1)

    # Apply circular mask
    if composite.shape[2] == 3:
        # No alpha channel, add one
        composite = cv2.cvtColor(composite, cv2.COLOR_BGR2BGRA)
    composite[:, :, 3] = cv2.bitwise_and(composite[:, :, 3], mask)

    # Convert first image to BGRA if necessary
    if first_img_cropped.shape[2] == 3:
        first_img_cropped = cv2.cvtColor(first_img_cropped, cv2.COLOR_BGR2BGRA)
    first_img_cropped[:, :, 3] = cv2.bitwise_and(first_img_cropped[:, :, 3], mask)    

    # Paste composite only where composite alpha is nonzero
    final_output = first_img_cropped.copy()

    alpha_mask = composite[:, :, 3] > 0  # True where composite is not transparent
    for c in range(4):  # Loop over 4 channels (B, G, R, A)
        final_output[:, :, c][alpha_mask] = composite[:, :, c][alpha_mask]

    return (final_output, pattern)
    

def save_to_data_folder(filename, output):
    global data_folder
    cv2.imwrite(os.path.join(data_folder, filename), output)

def composite_images(images, wave_function, line_thickness, rotation_angle=0):
    """Processes images, applies rotated wavy masks with offsets, and composites them."""
    global data_folder

    if not images:
        print("No images found in the folder.")
        return

    first_image = images[0]
    orig_height, orig_width, alpha = first_image.shape
    n = len(images)

    rotated_first_image = rotate_image_bound(first_image, rotation_angle)
    height, width, alpha = rotated_first_image.shape

    composite = np.zeros((height, width, alpha), dtype=np.uint8)

    # Generate and rotate the pattern before interlacing
    pattern = generate_custom_wavy_pattern(int(height*1.2), width, wave_function, line_thickness, n)
    
    end = pattern.shape[0]
    for image in images:
        rotated_image = rotate_image_bound(image, rotation_angle)

        pattern_interlace = pattern[end-height:end, :width]
        # Mask using rotated pattern
        masked = mask_image(rotated_image, pattern_interlace)

        # Composite the image
        composite = cv2.addWeighted(composite, 1, masked, 1, 0)

        end -= line_thickness

    pattern = rotate_image_bound(pattern, -rotation_angle)
    pattern = center_crop(pattern, orig_width, orig_height)

    # Increase brightness (optional)
    brightness_factor = 1 + (n - 1) / n
    brightness_factor = 1
    composite = np.clip(composite.astype(np.float32) * brightness_factor, 0, 255).astype(np.uint8)

    # Rotate back to original orientation
    final_composite = rotate_image_bound(composite, -rotation_angle)
    final_composite = center_crop(final_composite, orig_width, orig_height)
    
    return (final_composite, pattern)

def bottom_pad_to_match(img1, img2, fill=255):
    w1, h1 = img1.size
    w2, h2 = img2.size
    new_w = max(w1, w2)
    new_h = max(h1, h2)

    def pad_bottom(img, w, h):
        new_img = Image.new("L", (new_w, new_h), color=fill)
        offset_x = (new_w - w) // 2  # still center horizontally
        offset_y = 0  # top-align vertically
        new_img.paste(img, (offset_x, offset_y))
        return new_img

    return (pad_bottom(img1, w1, h1), pad_bottom(img2, w2, h2))

def center_pad_to_match(img1, img2, fill=255):
    w1, h1 = img1.size
    w2, h2 = img2.size
    new_w = max(w1, w2)
    new_h = max(h1, h2)

    def pad_center(img, w, h):
        new_img = Image.new("L", (new_w, new_h), color=fill)
        offset_x = (new_w - w) // 2
        offset_y = (new_h - h) // 2
        new_img.paste(img, (offset_x, offset_y))
        return new_img

    return (pad_center(img1, w1, h1), pad_center(img2, w2, h2))

def parse_custom_wave(expr_str):
    x = sp.symbols('x')
    expr = sp.sympify(expr_str)
    func = sp.lambdify(x, expr, modules=["numpy"])

    # 2. Return a wrapped version that catches problems
    def safe_func(x_val):
        try:
            result = func(x_val)
            # 3. Clean up NaN and infinities
            result = np.nan_to_num(result, nan=0.0, posinf=1e10, neginf=-1e10)
            return result
        except Exception as e:
            print(f"Error evaluating function at x={x_val}: {e}")
            return 0.0  # Default value on any serious error
    return safe_func

def match_lengths(list1, list2):
    len1, len2 = len(list1), len(list2)
    if len1 == len2:
        return list1, list2

    if len1 < len2:
        factor = (len2 + len1 - 1) // len1  # Ceiling division
        list1_extended = (list1 * factor)[:len2]
        return list1_extended, list2
    else:
        factor = (len1 + len2 - 1) // len2
        list2_extended = (list2 * factor)[:len1]
        return list1, list2_extended


@app.route('/generate_pattern', methods=['GET'])
def make_pattern():
    folder = str(request.args.get('folder'))
    resolution = float(request.args.get('resolution'))
    rotation_angle = float(request.args.get('rotation_angle'))
    custom_expr = str(request.args.get('wave_function'))
    custom_expr = insert_explicit_multiplication(custom_expr)
    
    images, wave_function = load_frames_and_function(folder, custom_expr)

    n = len(images)
    max_thickness = images[0].shape[0]/(n*10)
    line_thickness = map_resolution_to_thickness(resolution, max_thickness)
    
    final_composite, pattern = composite_images(images, wave_function, line_thickness, rotation_angle)

    save_to_data_folder("interlaced.png", final_composite)
    save_to_data_folder("pattern.png", pattern)

    max_angle = 360/(n*5)
    wedge_angle_deg = map_resolution_to_wedge_angle(resolution, max_angle)
    radial_composite, radial_pattern = composite_images_with_rotating_pattern(images, wedge_angle_deg, wave_function, 500)

    save_to_data_folder("radial_composite.png", radial_composite)
    save_to_data_folder("radial_pattern.png", radial_pattern)

    return "OK"

def load_frames_and_function(folder, custom_expr):
    if not os.path.exists(folder):
        print("Folder does not exist.")

    image_folder = sorted([os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(('png', 'jpg', 'jpeg'))])
    if not image_folder:
        print("No images found in the specified folder.")
    print(image_folder)
    images = [cv2.imread(x, cv2.IMREAD_UNCHANGED) for x in image_folder]

    try:
        wave_function = parse_custom_wave(custom_expr)
    except Exception as e:
        print(f"Invalid expression: {e}")

    return images, wave_function

def tile_images(
    scrambled_left, barrier_left, 
    scrambled_right, barrier_right,
    direction 
):
    HORIZONTAL = 1
    mode='RGB'

    # Get dimensions
    height_left, width_left = scrambled_left.shape[:2]
    height_right, width_right = scrambled_right.shape[:2]

    if direction == HORIZONTAL:
        new_width = width_left + width_right
        new_height = max(height_left, height_right)
        left_pos = (0, 0)
        right_pos = (width_left, 0)
    else:
        new_width = max(width_left, width_right)
        new_height = height_left + height_right
        left_pos = (0, 0)
        right_pos = (0, height_left)

    # Create blank canvases
    new_image = Image.new(mode=mode, size=(new_width, new_height))
    barrier_comp = Image.new(mode=mode, size=(new_width, new_height))

    # Paste scrambled images
    new_image.paste(Image.fromarray(scrambled_left.astype(np.uint8)), left_pos)
    new_image.paste(Image.fromarray(scrambled_right.astype(np.uint8)), right_pos)

    # Paste barrier images
    barrier_comp.paste(Image.fromarray(barrier_left.astype(np.uint8)), left_pos)
    barrier_comp.paste(Image.fromarray(barrier_right.astype(np.uint8)), right_pos)

    return new_image, barrier_comp

@app.route('/generate_woven', methods=['GET'])
def make_woven():
    folder = str(request.args.get('folder'))
    resolution = float(request.args.get('resolution'))
    rotation_angle = float(request.args.get('rotation_angle'))
    custom_expr = str(request.args.get('wave_function'))
    custom_expr = insert_explicit_multiplication(custom_expr)

    folder1 = str(request.args.get('folder1'))
    resolution1 = float(request.args.get('resolution1'))
    rotation_angle1 = float(request.args.get('rotation_angle1'))
    custom_expr1 = str(request.args.get('wave_function1'))
    custom_expr1 = insert_explicit_multiplication(custom_expr1)

    images, wave_function = load_frames_and_function(folder, custom_expr)
    images1, wave_function1 = load_frames_and_function(folder1, custom_expr1)

    n = len(images)
    max_thickness = images[0].shape[0]/(n*10)
    line_thickness = map_resolution_to_thickness(resolution, max_thickness)

    composite, pattern = composite_images(images, wave_function, line_thickness, rotation_angle)
    composite1, _ = composite_images(images1, wave_function, line_thickness, rotation_angle)

    line_thickness1 = map_resolution_to_thickness(resolution1, max_thickness)

    final_composite, pattern1 = composite_images([composite, composite1], wave_function1, line_thickness1, rotation_angle1)

    p1, p2 = bottom_pad_to_match(Image.fromarray(np.uint8(pattern)), Image.fromarray(np.uint8(pattern1)))
    # pattern_comp = ImageChops.multiply(p1, p2)

    save_to_data_folder("pattern-nest.png", pattern1)
    save_to_data_folder("interlaced.png", final_composite)
    save_to_data_folder("pattern.png", pattern)

    return "OK"

def closest_factor(n, target):
    # Get all factors of `target`
    factors = [i for i in range(1, target + 1) if target % i == 0]

    # Find the factor closest to `n`
    return min(factors, key=lambda x: abs(x - n))

def map_resolution_to_wedge_angle(resolution, max_angle):
    min_angle = 5

    # Invert the resolution scale: 1 → 1.0, 100 → 0.0
    normalized = (100 - resolution) / 99
    raw_angle = min_angle + normalized * (max_angle - min_angle)

    # Round to the closest factor of 360
    return closest_factor(raw_angle, 360)

def map_resolution_to_thickness(resolution, max_thickness):
    min_thickness = 3

    # Invert resolution: 100 → min_thickness, 1 → max_thickness
    normalized = (100 - resolution) / 99  # maps 1–100 to 1→1.0, 100→0.0
    thickness = min_thickness + normalized * (max_thickness - min_thickness)

    return int(round(thickness))

def calculate_scale_factor(image_path):
    # Load the image
    image = cv2.imread(image_path)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]

    # Filter using contour hierarchy
    cnts, hierarchy = cv2.findContours(thresh, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)[-2:]
    hierarchy = hierarchy[0]

    rectangle_areas = []
    for component in zip(cnts, hierarchy):
        currentContour = component[0]
        x, y, w, h = cv2.boundingRect(currentContour)
        rectangle_areas.append(w)
    
    # Sort rectangles by area (assuming the largest is the outer rectangle)
    # print(rectangle_areas)
    rectangle_areas = sorted(rectangle_areas)
    print(rectangle_areas)
    outer_width, inner_width = 1, 1
    try: 
        outer_width = rectangle_areas[2]
        inner_width = rectangle_areas[0]
    except: 
        print('found only one rectangle')

    # Calculate scale factor (linear scale factor)
    # Assuming similar shape, scale factor = sqrt(inner_area / outer_area)
    scale_factor = (outer_width / inner_width)

    return scale_factor

@app.route('/find_scale_factor', methods=['GET'])
def find_scale_factor():
    sf = calculate_scale_factor('fabobscura_ui/planes.png')
    print(sf)

    if sf > 10: sf = 1
    return str(sf)


# TODO: need to handle constants
def insert_explicit_multiplication(expr):
    orig = expr
    print(orig)
    # 1. Normalize spacing around math operators
    expr = re.sub(r'\s*([\+\-\*/\^\(\)])\s*', r'\1', expr)

    # 2. Insert * between a digit and a letter or open paren (e.g., 2x → 2*x, 3(x+1) → 3*(x+1))
    expr = re.sub(r'(\d)(?=[a-zA-Z\(])', r'\1*', expr)

    # 3. Insert * between constants and variable (e.g., pi x → pi*x)
    expr = re.sub(r'(pi|e)(?=\s*x)', r'\1*', expr)

    # 4. Insert * after ')' ONLY if it's followed by a digit, 'x', or another '('
    expr = re.sub(r'\)(?=\s*(\d|x|\())', r')*', expr)

    # 5. Remove leftover spaces
    expr = expr.replace(" ", "")

    try:
        func = parse_custom_wave(expr)
    except Exception as e:
        print("regex failed; using original expression....")

        return orig

    print("regex succeeded")
    return expr

if __name__ == '__main__':
    argparser = argparse.ArgumentParser()
    argparser.add_argument('--port', dest='port', default=3000, type=int, help='Port to serve the local service on')
    args = argparser.parse_args()

    # Run the flask application locally
    app.run(host='127.0.0.1', port=args.port)

