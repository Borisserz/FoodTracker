// Global coordinates state
const mouse = { x: -1000, y: -1000, active: false };

// --- 1. INTERACTIVE COSMIC CANVAS BACKGROUND (Warping Grid & Particles) ---
const canvas = document.getElementById('space-canvas');
const ctx = canvas.getContext('2d');

let width = canvas.width = window.innerWidth;
let height = canvas.height = window.innerHeight;

// Track window resizing
window.addEventListener('resize', () => {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
    initGrid();
});

// Track mouse positioning
window.addEventListener('mousemove', (e) => {
    mouse.x = e.clientX;
    mouse.y = e.clientY;
    mouse.active = true;
    
    // Spawn trailing glowing dust particles
    if (Math.random() < 0.25) {
        spawnParticle(mouse.x, mouse.y);
    }
});

window.addEventListener('mouseleave', () => {
    mouse.active = false;
    mouse.x = -1000;
    mouse.y = -1000;
});

// Grid configuration
const gridSpacing = 60;
let gridPoints = [];

function initGrid() {
    gridPoints = [];
    for (let x = 0; x < width + gridSpacing; x += gridSpacing) {
        for (let y = 0; y < height + gridSpacing; y += gridSpacing) {
            gridPoints.push({
                x: x,
                y: y,
                ox: x, // Original X
                oy: y  // Original Y
            });
        }
    }
}

// Particle system for glowing trails
let particles = [];
const particleColors = ['#ff79c6', '#ffb86c', '#50fa7b', '#8be9fd', '#bd93f9'];

function spawnParticle(x, y) {
    particles.push({
        x: x,
        y: y,
        vx: (Math.random() - 0.5) * 1.5,
        vy: (Math.random() - 0.5) * 1.5 - 0.5,
        size: Math.random() * 6 + 4,
        color: particleColors[Math.floor(Math.random() * particleColors.length)],
        opacity: 0.8,
        life: 1.0,
        decay: Math.random() * 0.015 + 0.01
    });
}

// Nebula glows background parameters
let nebulaAngle = 0;

// Main background animation loop
function animateBackground() {
    ctx.clearRect(0, 0, width, height);
    
    // Deep dark space background gradient
    const bgGrad = ctx.createLinearGradient(0, 0, width, height);
    bgGrad.addColorStop(0, '#040508');
    bgGrad.addColorStop(0.5, '#090a12');
    bgGrad.addColorStop(1, '#040508');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, width, height);
    
    // Draw rotating colored nebula glows behind grid
    nebulaAngle += 0.002;
    const nebX1 = width * 0.3 + Math.sin(nebulaAngle) * 80;
    const nebY1 = height * 0.3 + Math.cos(nebulaAngle) * 80;
    const nebGrad1 = ctx.createRadialGradient(nebX1, nebY1, 10, nebX1, nebY1, width * 0.5);
    nebGrad1.addColorStop(0, 'rgba(255, 121, 198, 0.06)'); // Pink
    nebGrad1.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = nebGrad1;
    ctx.fillRect(0, 0, width, height);

    const nebX2 = width * 0.7 - Math.cos(nebulaAngle * 0.8) * 100;
    const nebY2 = height * 0.7 + Math.sin(nebulaAngle * 0.8) * 100;
    const nebGrad2 = ctx.createRadialGradient(nebX2, nebY2, 10, nebX2, nebY2, width * 0.5);
    nebGrad2.addColorStop(0, 'rgba(139, 233, 253, 0.05)'); // Cyan
    nebGrad2.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = nebGrad2;
    ctx.fillRect(0, 0, width, height);

    // Render & Warp space grid
    const warpRadius = 220;
    const warpForceMax = 45;
    
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.04)';
    ctx.lineWidth = 1;
    
    // Warp point coordinates based on mouse
    gridPoints.forEach(p => {
        if (mouse.active) {
            const dx = p.ox - mouse.x;
            const dy = p.oy - mouse.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            
            if (dist < warpRadius) {
                // Formula to pull points toward the mouse or push them away
                const factor = (warpRadius - dist) / warpRadius;
                // Pulling/gravity effect
                p.x = p.ox - (dx / dist) * factor * warpForceMax;
                p.y = p.oy - (dy / dist) * factor * warpForceMax;
            } else {
                // Return to original coordinates smoothly
                p.x += (p.ox - p.x) * 0.1;
                p.y += (p.oy - p.y) * 0.1;
            }
        } else {
            p.x += (p.ox - p.x) * 0.1;
            p.y += (p.oy - p.y) * 0.1;
        }
        
        // Draw grid intersection dots
        ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
        ctx.fillRect(p.x - 1, p.y - 1, 2, 2);
    });

    // Draw horizontal grid lines
    for (let i = 0; i < gridPoints.length; i++) {
        const p1 = gridPoints[i];
        
        // Find next point horizontally
        const nextHorizontal = gridPoints.find(p => p.oy === p1.oy && p.ox === p1.ox + gridSpacing);
        if (nextHorizontal) {
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(nextHorizontal.x, nextHorizontal.y);
            ctx.stroke();
        }
        
        // Find next point vertically
        const nextVertical = gridPoints.find(p => p.ox === p1.ox && p.oy === p1.oy + gridSpacing);
        if (nextVertical) {
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(nextVertical.x, nextVertical.y);
            ctx.stroke();
        }
    }
    
    // Draw glowing cursor trails
    particles.forEach((p, idx) => {
        p.x += p.vx;
        p.y += p.vy;
        p.life -= p.decay;
        
        if (p.life <= 0) {
            particles.splice(idx, 1);
            return;
        }
        
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size * p.life, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.globalAlpha = p.opacity * p.life;
        ctx.shadowBlur = 15;
        ctx.shadowColor = p.color;
        ctx.fill();
        
        // Reset shadow
        ctx.shadowBlur = 0;
        ctx.globalAlpha = 1.0;
    });
    
    requestAnimationFrame(animateBackground);
}

// Run canvas logic
initGrid();
animateBackground();


// --- 2. MAGNETIC HOVER EFFECT FOR BUTTONS ---
const magneticButtons = document.querySelectorAll('.btn-magnetic');

magneticButtons.forEach(btn => {
    btn.addEventListener('mousemove', (e) => {
        const rect = btn.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        
        // Pull button slightly towards cursor
        btn.style.transform = `translate(${x * 0.35}px, ${y * 0.35}px) scale(1.05)`;
        btn.style.transition = 'transform 0.1s cubic-bezier(0.25, 0.8, 0.25, 1)';
    });
    
    btn.addEventListener('mouseleave', () => {
        btn.style.transform = 'translate(0px, 0px)';
        btn.style.transition = 'transform 0.5s cubic-bezier(0.25, 0.8, 0.25, 1.4)';
    });
});


// --- 3. SCROLL REVEAL TRIGGERS ---
const scrollTriggers = document.querySelectorAll('.scroll-trigger');

const revealCallback = (entries, observer) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            // Stop observing once visible to optimize
            observer.unobserve(entry.target);
        }
    });
};

const revealObserver = new IntersectionObserver(revealCallback, {
    root: null,
    threshold: 0.15
});

scrollTriggers.forEach(trigger => {
    revealObserver.observe(trigger);
});


// --- 4. INTERACTIVE BEFORE / AFTER SLIDER DRAGGING ---
const slider = document.getElementById('ba-slider');
const afterImage = document.querySelector('.image-after');
const sliderBar = document.getElementById('ba-bar');

if (slider && afterImage && sliderBar) {
    let isDragging = false;
    
    const updateSlider = (clientX) => {
        const rect = slider.getBoundingClientRect();
        const offsetX = clientX - rect.left;
        let percent = (offsetX / rect.width) * 100;
        
        // Constraint boundaries
        if (percent < 0) percent = 0;
        if (percent > 100) percent = 100;
        
        // Apply slider widths/positions
        // .image-after is positioned on the right and masked/revealed by width,
        // so to sweep from left-to-right:
        afterImage.style.width = (100 - percent) + '%';
        sliderBar.style.left = percent + '%';
    };
    
    // Mouse Events
    slider.addEventListener('mousedown', (e) => {
        isDragging = true;
        updateSlider(e.clientX);
    });
    
    window.addEventListener('mousemove', (e) => {
        if (!isDragging) return;
        updateSlider(e.clientX);
    });
    
    window.addEventListener('mouseup', () => {
        isDragging = false;
    });
    
    // Touch Events (Mobile)
    slider.addEventListener('touchstart', (e) => {
        isDragging = true;
        updateSlider(e.touches[0].clientX);
    });
    
    window.addEventListener('touchmove', (e) => {
        if (!isDragging) return;
        updateSlider(e.touches[0].clientX);
    });
    
    window.addEventListener('touchend', () => {
        isDragging = false;
    });
}


// --- 5. INTERACTIVE COACH CONVERSATION WIDGET ---
function askCoach(questionText) {
    const chatContainer = document.querySelector('.chat-container');
    if (!chatContainer) return;
    
    // 1. Remove suggestions panel
    const suggestions = document.querySelector('.chat-suggestions');
    if (suggestions) suggestions.remove();
    
    // 2. Append User chat bubble
    const userBubble = document.createElement('div');
    userBubble.className = 'chat-bubble user';
    userBubble.innerText = questionText;
    chatContainer.appendChild(userBubble);
    
    // Scroll to bottom
    chatContainer.scrollTop = chatContainer.scrollHeight;
    
    // 3. Generate Coach response
    let coachReply = '';
    if (questionText.includes('carbs')) {
        coachReply = "Carbohydrates are essential pre-workout to top off glycogen stores! Focus on easily digestible complex carbs 1.5 - 2 hours prior, like oatmeal or bananas.";
    } else if (questionText.includes('metabolism')) {
        coachReply = "To boost your metabolism, focus on strength training to increase lean muscle mass, eat a high-protein diet (protein has a high thermal effect), and stay hydrated!";
    } else {
        coachReply = "That's a great question. Balancing nutrition is highly individual. Coach Stella will break down the exact parameters based on your metric logs!";
    }
    
    // 4. Create typing indicator
    const typingBubble = document.createElement('div');
    typingBubble.className = 'chat-bubble bot';
    typingBubble.innerText = 'typing...';
    
    setTimeout(() => {
        chatContainer.appendChild(typingBubble);
        chatContainer.scrollTop = chatContainer.scrollHeight;
        
        // 5. Replace typing with real answer
        setTimeout(() => {
            typingBubble.innerText = coachReply;
            typingBubble.classList.add('typing-effect');
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }, 1200);
    }, 500);
}
