### HTML Presentation Template

```html
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>📊 Meine Präsentation</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Roboto:wght@300;400;500;700&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Roboto', sans-serif;
            background: #181a1b;
            color: #f1f1f1;
            font-size: 14px;
        }
        .slideshow-container {
            max-width: 1100px;
            margin: 30px auto;
            background: #232526;
            border-radius: 18px;
            box-shadow: 0 4px 24px rgba(0,0,0,0.25);
            overflow: hidden;
            position: relative;
        }
        .slide {
            display: none;
            padding: 40px;
            min-height: 600px;
            animation: fadein 0.5s;
        }
        .slide.active {
            display: block;
        }
        @keyframes fadein {
            from { opacity: 0; }
            to { opacity: 1; }
        }
        .header {
            background: linear-gradient(135deg, #ff6b6b, #4ecdc4);
            color: white;
            padding: 28px;
            text-align: center;
            border-radius: 0 0 18px 18px;
        }
        .section-title {
            font-family: 'Orbitron', monospace;
            color: #feca57;
            text-align: center;
            margin: 25px 0;
            font-size: 1.4em;
        }
        .footer {
            background: #232526;
            color: #fff;
            padding: 22px 10px;
            text-align: center;
            font-size: 1.05em;
            border-radius: 18px 18px 0 0;
            margin-top: 30px;
        }
        .nav-btn {
            background: linear-gradient(135deg, #feca57, #ff9ff3);
            color: #181a1b;
            border: none;
            border-radius: 8px;
            padding: 10px 24px;
            font-size: 1.1em;
            cursor: pointer;
        }
        .nav-btn:hover {
            background: linear-gradient(135deg, #ff9ff3, #feca57);
        }
        img, svg {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 20px auto;
        }
    </style>
</head>
<body>
    <div class="slideshow-container">

        <!-- Slide 1: Title -->
        <div class="slide active" id="slide-0">
            <div class="header">
                <h1>📊 Meine Präsentation</h1>
                <div class="subtitle">Ein Überblick über mein Projekt</div>
            </div>
            <h2 class="section-title">Willkommen!</h2>
            <p>In dieser Präsentation werden wir verschiedene Themen behandeln.</p>
            <div class="footer">
                <span>📊 Slide 1: Einführung</span>
            </div>
        </div>

        <!-- Slide 2: Media -->
        <div class="slide" id="slide-1">
            <h2 class="section-title">Medienbeispiele</h2>
            <img src="example-image.png" alt="Beispielbild">
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
                <circle cx="50" cy="50" r="40" fill="orange" />
            </svg>
            <div class="footer">
                <span>📊 Slide 2: Medien</span>
            </div>
        </div>

        <!-- Slide 3: Conclusion -->
        <div class="slide" id="slide-2">
            <h2 class="section-title">Fazit</h2>
            <p>Vielen Dank für Ihre Aufmerksamkeit!</p>
            <div class="footer">
                <span>📊 Slide 3: Fazit</span>
            </div>
        </div>

        <div style="text-align:center; margin: 30px 0;">
            <button class="nav-btn" id="prevBtn"><i class="fa-solid fa-chevron-left"></i> Zurück</button>
            <button class="nav-btn" id="nextBtn">Weiter <i class="fa-solid fa-chevron-right"></i></button>
        </div>
    </div>

    <script>
        // Slide navigation logic
        const slides = document.querySelectorAll('.slide');
        const prevBtn = document.getElementById('prevBtn');
        const nextBtn = document.getElementById('nextBtn');
        let currentSlide = 0;

        function showSlide(idx) {
            slides.forEach((slide, i) => {
                slide.classList.toggle('active', i === idx);
            });
            prevBtn.disabled = idx === 0;
            nextBtn.disabled = idx === slides.length - 1;
        }

        prevBtn.addEventListener('click', () => {
            if (currentSlide > 0) {
                currentSlide--;
                showSlide(currentSlide);
            }
        });
        nextBtn.addEventListener('click', () => {
            if (currentSlide < slides.length - 1) {
                currentSlide++;
                showSlide(currentSlide);
            }
        });

        showSlide(currentSlide);
    </script>
</body>
</html>
```

### Explanation of the Template

1. **Structure**: The presentation consists of a container for slides, each slide having a header, content, and footer.

2. **Styling**: The CSS styles are designed to create a visually appealing layout, with a dark background and colorful headers. The `@import` statement is used to include custom fonts.

3. **Media Support**: The template includes an example of how to add images (PNG) and SVG graphics. You can replace `example-image.png` with the path to your own image file.

4. **Navigation**: JavaScript is used to handle slide navigation, allowing users to move between slides using "Zurück" and "Weiter" buttons.

5. **Responsive Design**: The images and SVGs are set to be responsive, ensuring they fit well within the slide regardless of screen size.

### Usage

- Replace the content in each slide with your own text, images, and SVGs.
- Add more slides by duplicating the `<div class="slide">...</div>` structure and updating the content accordingly.
- Ensure that any media files you want to include are correctly linked in the `src` attributes.

This template provides a solid foundation for creating a multimedia presentation that is both functional and visually appealing.