// Slide navigation logic
document.addEventListener('DOMContentLoaded', function() {
    const slides = document.querySelectorAll('.slide');
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');
    const signpostIcons = document.querySelectorAll('.signpost-bar .signpost-icon');
    let currentSlide = 0;

    // Debug logs
    console.log('Slides:', slides.length);
    console.log('Signpost icons:', signpostIcons.length);

    function showSlide(idx) {
        slides.forEach((slide, i) => {
            slide.classList.toggle('active', i === idx);
        });
        signpostIcons.forEach((icon, i) => {
            icon.classList.toggle('active', i === idx);
        });
        prevBtn.disabled = idx === 0;
        nextBtn.disabled = idx === slides.length - 1;
        currentSlide = idx;
        console.log('Switched to slide', idx);
    }

    prevBtn.addEventListener('click', () => {
        if (currentSlide > 0) {
            showSlide(currentSlide - 1);
        }
    });
    nextBtn.addEventListener('click', () => {
        if (currentSlide < slides.length - 1) {
            showSlide(currentSlide + 1);
        }
    });

    // Signpost navigation
    signpostIcons.forEach((icon, idx) => {
        icon.addEventListener('click', () => {
            showSlide(idx);
        });
    });

    // Keyboard navigation
    document.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowRight' || e.key === 'PageDown') {
            nextBtn.click();
        } else if (e.key === 'ArrowLeft' || e.key === 'PageUp') {
            prevBtn.click();
        }
    });

    showSlide(currentSlide);

    // PlantUML dynamic rendering for energyLIVE Flowchart (slide 5)
    const energyLivePlantUML = `
    @startuml
    !theme plain
    actor Benutzer as User
    rectangle "Zählerkasten\\nmit energyLIVE" as Meter {
      [energyLIVE]
    }
    User --> Meter : Stromverbrauch
    Meter --> "WLAN\\n(Heimnetz)" : Datenübertragung
    "WLAN\\n(Heimnetz)" --> "smartENERGY-Cloud" : Verbrauchsdaten
    "smartENERGY-Cloud" --> "Dashboard\\n(App/Web)" : Visualisierung
    @enduml
    `;

    function renderPlantUML(id, plantumlCode) {
        if (typeof plantumlEncoder === 'undefined') return;
        const encoded = plantumlEncoder.encode(plantumlCode);
        const url = "https://www.plantuml.com/plantuml/svg/" + encoded;
        const img = document.getElementById(id);
        if (img) img.src = url;
    }

    renderPlantUML("energyLivePlantUML", energyLivePlantUML);

    // Chart.js animated chart for Slide 7
    if (document.getElementById('energyChart')) {
        const ctx = document.getElementById('energyChart').getContext('2d');
        // Example data, replace with real data as needed
        const data = {
            labels: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'],
            datasets: [{
                label: 'Energieverbrauch (kWh)',
                data: [2, 4, 6, 8, 5, 3],
                backgroundColor: 'rgba(130, 200, 40, 0.5)',
                borderColor: '#82C828',
                borderWidth: 2,
                fill: true,
                tension: 0.4
            }]
        };
        const config = {
            type: 'line',
            data: data,
            options: {
                responsive: true,
                plugins: {
                    legend: { display: true },
                    title: { display: true, text: 'Tagesverbrauch' }
                },
                animation: {
                    duration: 1500,
                    easing: 'easeInOutQuart'
                }
            }
        };
        new Chart(ctx, config);
    }

    // Fade-in/progressive reveal for .fade-in elements
    function fadeInElements() {
        document.querySelectorAll('.fade-in').forEach(el => {
            el.style.opacity = 0;
            setTimeout(() => {
                el.style.transition = 'opacity 1s';
                el.style.opacity = 1;
            }, 400);
        });
    }
    document.addEventListener('DOMContentLoaded', fadeInElements);
});