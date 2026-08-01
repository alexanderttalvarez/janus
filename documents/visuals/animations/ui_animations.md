# UI Animations

## Toast Notification Slide (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Toast slides in from bottom-right, then fades out. |
| **Slide in** | 0.3 seconds, ease-out |
| **Display** | 5-10 seconds (based on priority) |
| **Fade out** | 0.3 seconds, ease-in |
| **MVP** | Simple position tween + opacity tween. |

## Panel Open/Close (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Info panels slide in from right edge. |
| **Open** | 0.2 seconds, ease-out |
| **Close** | 0.2 seconds, ease-in |
| **MVP** | Simple position tween. |

## Camera Rotation (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Camera rotates 90° left or right. |
| **Duration** | 0.15 seconds |
| **Easing** | Cubic ease-out |
| **MVP** | Tween on CameraRig rotation. |

## Button Hover/Click (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual feedback on UI button interaction. |
| **Hover** | Slight brightness increase or scale up (1.05x) |
| **Click** | Brief scale down (0.95x) then back |
| **MVP** | Godot built-in button hover/click effects. |

## Reuse Opportunities

- All toast notifications share the same slide animation
- All panels share the same open/close animation
- All buttons share the same hover/click animation
- Use Godot's Tween node or built-in Control animations
