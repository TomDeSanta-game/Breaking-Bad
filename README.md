# 🎮 Breaking Bad - Pixel Art Game 🧪

A work-in-progress pixel art game based on the Breaking Bad series, following Walter White's journey from chemistry teacher to methamphetamine manufacturer.

## ✅ Current Implementations

### 🏃 Character System
- Basic movement and animation system
- Health system foundations
- Sprint mechanic with stamina limitations
- Interaction system for objects and NPCs

### 🔍 Core Systems
- Tension engine in early stages
  - Environment effects based on player stress level
  - Basic police response framework
- 💊 Drug effects system
  - Visual effects during substance influence
  - Initial implementation of withdrawal effects
- 📷 Surveillance camera system
  - Multiple camera view switching
  - Detection mechanics for narrative events
  - Emergency mode for story sequences

### 🌃 Environment
- Basic day/night lighting system
- Interactive doors and objects
- Scene transitions between key locations

### 📜 Narrative Elements
- Dialog system integration (Dialogic)
- Initial storyline segments:
  - Cancer diagnosis scene
  - Ride with Hank sequence
  - Initial family interactions

## ⏳ Development Roadmap

- 🧪 Chemistry-based manufacturing mechanics
- 💰 Street dealing system
- 🚔 Comprehensive police AI and wanted system
- 👥 Advanced NPC interactions and scheduling
- 🗺️ Territory control mechanics
- 🎬 Post-processing visual system
- ✅ Quest tracking system

## 🎮 Controls
- WASD/Arrow Keys: Movement
- Shift: Sprint
- E: Interact
- ESC: Pause/Exit camera view
- 1-9: Switch between surveillance cameras

## Particle System

The Breaking Bad game includes a comprehensive particle system for creating immersive visual effects:

### Types of Effects
- **Explosions**: Small and large explosion effects with smoke and fire particles
- **Chemical Reactions**: Blue, green, and yellow chemical bubbling effects for lab scenes
- **Firefight Effects**: Muzzle flashes, bullet impacts, and blood splatters
- **Environmental Effects**: Glass shattering and smoke puffs

### Usage
Particle effects can be triggered from any script by accessing the global ParticleSystemManager:

```gdscript
# Spawn an explosion
ParticleSystemManager.spawn_explosion(position, large, scale_factor)

# Create chemical reactions in the lab
ParticleSystemManager.spawn_chemical_reaction(position, color, scale_factor, duration)

# Gunfight effects
ParticleSystemManager.spawn_muzzle_flash(position, rotation, scale_factor)
ParticleSystemManager.spawn_bullet_impact(position, normal, scale_factor)
ParticleSystemManager.spawn_blood_splatter(position, direction, scale_factor)

# Environmental effects
ParticleSystemManager.spawn_glass_shatter(position, scale_factor)
ParticleSystemManager.spawn_smoke_puff(position, scale_factor, duration)
```

Camera effects are automatically integrated with particle systems, creating screen shake and impact effects when appropriate.

---
*This project is in active development. See Markdown/update.md for development progress.*
