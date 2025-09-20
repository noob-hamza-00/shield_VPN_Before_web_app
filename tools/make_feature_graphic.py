from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

# Config
WIDTH, HEIGHT = 1024, 500
BG_GRADIENT_START = (5, 18, 45)   # deep navy
BG_GRADIENT_END = (10, 38, 95)    # blue
TITLE = "Shield VPN"
SUBTITLE = "One tap privacy. Fast, secure access worldwide."
OUTPUT = Path("store/graphics/feature_graphic_1024x500.png")
LOGO_PATH = Path("assets/images/logomybrother.png")
FONT_TITLE = None  # path to custom TTF if desired
FONT_SUB = None

# Fallback fonts if not available
TITLE_SIZE = 82
SUB_SIZE = 26


def ensure_dirs():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)


def lerp(a, b, t):
    return int(a + (b - a) * t)


def gradient_bg():
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_GRADIENT_START)
    draw = ImageDraw.Draw(img)
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        r = lerp(BG_GRADIENT_START[0], BG_GRADIENT_END[0], t)
        g = lerp(BG_GRADIENT_START[1], BG_GRADIENT_END[1], t)
        b = lerp(BG_GRADIENT_START[2], BG_GRADIENT_END[2], t)
        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))
    # subtle vignette
    vignette = Image.new("L", (WIDTH, HEIGHT), 0)
    vd = ImageDraw.Draw(vignette)
    vd.rectangle([0, 0, WIDTH, HEIGHT], fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(120))
    vignette_rgb = Image.new("RGB", (WIDTH, HEIGHT), (0, 0, 0))
    vignette_rgb.putalpha(vignette.point(lambda p: int(p * 0.35)))
    img = img.convert("RGBA")
    img.alpha_composite(vignette_rgb)
    return img


def load_logo(max_height=280):
    if not LOGO_PATH.exists():
        return None
    logo = Image.open(LOGO_PATH).convert("RGBA")
    scale = min(max_height / logo.height, 1.0)
    new_size = (int(logo.width * scale), int(logo.height * scale))
    return logo.resize(new_size, Image.LANCZOS)


def _measure(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont):
    try:
        bbox = draw.textbbox((0, 0), text, font=font)
        return bbox[2] - bbox[0], bbox[3] - bbox[1]
    except Exception:
        return draw.textlength(text, font=font), TITLE_SIZE


def draw_text(img):
    draw = ImageDraw.Draw(img)
    # Load fonts
    try:
        if FONT_TITLE:
            ft = ImageFont.truetype(FONT_TITLE, TITLE_SIZE)
        else:
            # Try common fonts, fallback to default
            try:
                ft = ImageFont.truetype("arial.ttf", TITLE_SIZE)
            except Exception:
                try:
                    ft = ImageFont.truetype("DejaVuSans-Bold.ttf", TITLE_SIZE)
                except Exception:
                    ft = ImageFont.load_default()
    except Exception:
        ft = ImageFont.load_default()
    try:
        if FONT_SUB:
            fs = ImageFont.truetype(FONT_SUB, SUB_SIZE)
        else:
            try:
                fs = ImageFont.truetype("arial.ttf", SUB_SIZE)
            except Exception:
                try:
                    fs = ImageFont.truetype("DejaVuSans.ttf", SUB_SIZE)
                except Exception:
                    fs = ImageFont.load_default()
    except Exception:
        fs = ImageFont.load_default()

    # Layout
    margin = 60
    x_text = 520
    y_title = 150

    # Title
    draw.text((x_text, y_title), TITLE, font=ft, fill=(255, 255, 255))

    # Sub
    y_sub = y_title + int(TITLE_SIZE * 0.86) + 22
    # Wrap subtitle if needed to keep within canvas
    max_width = WIDTH - x_text - margin
    words = SUBTITLE.split()
    line = ""
    y = y_sub
    for w in words:
        test = (line + " " + w).strip()
        tw, th = _measure(draw, test, fs)
        if tw > max_width and line:
            draw.text((x_text, y), line, font=fs, fill=(220, 230, 255))
            y += th + 6
            line = w
        else:
            line = test
    if line:
        draw.text((x_text, y), line, font=fs, fill=(220, 230, 255))

    return img


def compose():
    bg = gradient_bg()
    logo = load_logo()
    if logo is not None:
        # place logo on left, centered vertically
        x = 120
        y = (HEIGHT - logo.height) // 2
        bg.alpha_composite(logo, (x, y))
    return draw_text(bg)


def main():
    try:
        ensure_dirs()
        img = compose()
        # Ensure RGB and save as PNG
        out = img.convert("RGB")
        out.save(OUTPUT, format="PNG", optimize=True)
        print(f"Saved feature graphic to {OUTPUT}")
    except Exception as e:
        print("Failed to generate feature graphic:", e)
        raise


if __name__ == "__main__":
    main()
