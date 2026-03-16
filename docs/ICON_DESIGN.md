# Yapper Icon Design Guide

## Concept

The Yapper icon represents voice-to-text dictation with AI processing capabilities.

**Design Elements:**
- **Waveform**: Represents voice/audio input
- **Flow**: Dynamic, modern aesthetic suggesting smooth processing
- **Color**: Blue gradient (tech/AI) with accent colors

## Icon Specifications

### Colors
- Primary: `#4A90E2` (Blue)
- Secondary: `#7C3AED` (Purple)
- Accent: `#10B981` (Green, for active states)
- Background: Gradient from primary to secondary

### Design
The icon features a stylized waveform that forms a "V" shape, representing both "Voice" and "Yapper". The waveform has smooth curves and a modern, minimal aesthetic.

## SVG Template

```svg
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <!-- Background gradient -->
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4A90E2;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#7C3AED;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="waveGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#ffffff;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#f0f9ff;stop-opacity:0.9" />
    </linearGradient>
  </defs>

  <!-- Rounded square background -->
  <rect width="512" height="512" rx="115" fill="url(#bgGradient)"/>

  <!-- Waveform forming V shape -->
  <g fill="url(#waveGradient)">
    <!-- Left wave bars (descending) -->
    <rect x="80" y="180" width="40" height="152" rx="20"/>
    <rect x="140" y="200" width="40" height="112" rx="20"/>
    <rect x="200" y="220" width="40" height="72" rx="20"/>

    <!-- Right wave bars (ascending) -->
    <rect x="272" y="220" width="40" height="72" rx="20"/>
    <rect x="332" y="200" width="40" height="112" rx="20"/>
    <rect x="392" y="180" width="40" height="152" rx="20"/>
  </g>

  <!-- Microphone icon overlay (subtle) -->
  <circle cx="256" cy="340" r="30" fill="#10B981" opacity="0.3"/>
  <ellipse cx="256" cy="330" rx="15" ry="20" fill="white"/>
  <line x1="256" y1="350" x2="256" y2="370" stroke="white" stroke-width="4" stroke-linecap="round"/>
  <path d="M 240 370 Q 256 375 272 370" stroke="white" stroke-width="4" fill="none" stroke-linecap="round"/>
</svg>
```

## Generating Icon Assets

### Option 1: Using Sketch or Figma
1. Import the SVG above
2. Create artboards for each required size: 16, 32, 64, 128, 256, 512, 1024
3. Export as PNG @1x and @2x for each size
4. Place files in `Sources/Yapper/Resources/Assets.xcassets/AppIcon.appiconset/`

### Option 2: Using ImageMagick or similar
```bash
# Install ImageMagick if needed
brew install imagemagick librsvg

# Save the SVG above as yapper-icon.svg, then:
for size in 16 32 64 128 256 512 1024; do
  magick -background none yapper-icon.svg -resize ${size}x${size} icon_${size}x${size}.png
  magick -background none yapper-icon.svg -resize $((size*2))x$((size*2)) icon_${size}x${size}@2x.png
done
```

### Option 3: Using Online Tools
1. Visit https://icon.kitchen or https://appicon.co
2. Upload the SVG or create a similar design
3. Download macOS icon set
4. Extract to AppIcon.appiconset folder

## Menubar Icon

For the menubar, use a simpler monochrome version:

```svg
<svg width="22" height="22" viewBox="0 0 22 22" xmlns="http://www.w3.org/2000/svg">
  <!-- Simple waveform for menubar -->
  <g fill="currentColor">
    <rect x="2" y="8" width="2" height="6" rx="1"/>
    <rect x="6" y="6" width="2" height="10" rx="1"/>
    <rect x="10" y="4" width="2" height="14" rx="1"/>
    <rect x="14" y="6" width="2" height="10" rx="1"/>
    <rect x="18" y="8" width="2" height="6" rx="1"/>
  </g>
</svg>
```

The menubar icon is already set in `YapperApp.swift` using SF Symbols (`waveform`). You can replace it with a custom icon by:

1. Add the menubar SVG to Assets as "MenubarIcon"
2. Update YapperApp.swift:
```swift
button.image = NSImage(named: "MenubarIcon")
```

## Current Status

- ✅ Asset catalog structure created
- ✅ Icon design specification complete
- ⏳ Actual icon images need to be generated
- ⏳ Package.swift needs to reference Assets as resources

## Next Steps

1. Generate icon images using one of the methods above
2. Update Package.swift to include Assets as resources
3. Test the icon appears correctly in Finder and dock
