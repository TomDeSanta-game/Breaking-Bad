extends Node

enum SignalCategory {
	PLAYER,
	TENSION,
	INTERACTION,
	ENVIRONMENT,
	NOTIFICATION,
	PHONE,
	CAMERA,
	PARTICLE,
	DRUG_EFFECT,
	GAMEPLAY,
	VISUAL_EFFECTS,
	TIME_EFFECTS,
	BUSINESS
}

@warning_ignore("unused_signal") signal health_changed(new_health, max_health)
@warning_ignore("unused_signal") signal heat_changed(new_heat, max_heat)
@warning_ignore("unused_signal") signal stamina_changed(new_stamina, max_stamina)
@warning_ignore("unused_signal") signal player_died
@warning_ignore("unused_signal") signal player_detected(npc_type)
@warning_ignore("unused_signal") signal player_state_changed(new_state)
@warning_ignore("unused_signal") signal player_objective_updated(objective_id, text, completed)
@warning_ignore("unused_signal") signal player_event(event_type, data)
@warning_ignore("unused_signal") signal player_damaged(damage_amount, attacker_position)
@warning_ignore("unused_signal") signal player_health_changed(health, max_health)

@warning_ignore("unused_signal") signal tension_changed(current, old)
@warning_ignore("unused_signal") signal tension_level_changed(level_name, previous_level)
@warning_ignore("unused_signal") signal max_tension_reached
@warning_ignore("unused_signal") signal min_tension_reached
@warning_ignore("unused_signal") signal threshold_crossed(threshold_name, direction, threshold_value, current_value)
@warning_ignore("unused_signal") signal heat_level_changed(new_level, old_level)
@warning_ignore("unused_signal") signal police_alerted(position, intensity)

@warning_ignore("unused_signal") signal door_opened(door_id)
@warning_ignore("unused_signal") signal door_closed(door_id)
@warning_ignore("unused_signal") signal item_picked_up(item_id, item_data)
@warning_ignore("unused_signal") signal item_used(item_id, target_id)
@warning_ignore("unused_signal") signal objective_completed(objective_id)
@warning_ignore("unused_signal") signal objective_added(objective_id, text)
@warning_ignore("unused_signal") signal show_interaction_prompt(text)
@warning_ignore("unused_signal") signal hide_interaction_prompt

@warning_ignore("unused_signal") signal notification_shown(id, notification_type, message)
@warning_ignore("unused_signal") signal notification_hidden(id)
@warning_ignore("unused_signal") signal show_notification(message, notification_type, duration)
@warning_ignore("unused_signal") signal show_mission_text(title, description)
@warning_ignore("unused_signal") signal notification_requested(title, message, type, duration)

@warning_ignore("unused_signal") signal music_changed(music_name)
@warning_ignore("unused_signal") signal ambient_changed(ambient_name)
@warning_ignore("unused_signal") signal weather_changed(type, intensity)
@warning_ignore("unused_signal") signal lighting_state_changed(state_name)
@warning_ignore("unused_signal") signal area_changed(area_name)

@warning_ignore("unused_signal") signal phone_call_started(caller_id, caller_data)
@warning_ignore("unused_signal") signal phone_call_missed(caller_id)
@warning_ignore("unused_signal") signal phone_call_ended(caller_id, duration)
@warning_ignore("unused_signal") signal phone_call_held(caller_id)
@warning_ignore("unused_signal") signal phone_power_changed(is_powered)
@warning_ignore("unused_signal") signal phone_silent_changed(is_silenced)
@warning_ignore("unused_signal") signal phone_gps_changed(is_tracked)

@warning_ignore("unused_signal") signal camera_effect_started(effect_name)
@warning_ignore("unused_signal") signal camera_effect_ended(effect_name)

@warning_ignore("unused_signal") signal drug_effect_started(effect_name, duration)
@warning_ignore("unused_signal") signal drug_effect_ended(effect_name)
@warning_ignore("unused_signal") signal drug_effect_applied(effect_name, intensity)
@warning_ignore("unused_signal") signal drug_effect_parameter_changed(parameter_name, value)

@warning_ignore("unused_signal") signal vfx_started(effect_type, position)
@warning_ignore("unused_signal") signal vfx_completed(effect_type, position)
@warning_ignore("unused_signal") signal chemical_reaction_occurred(chemical_type, position, intensity)
@warning_ignore("unused_signal") signal explosion_occurred(position, size, damage_radius)
@warning_ignore("unused_signal") signal gunshot_fired(position, direction, weapon_type)
@warning_ignore("unused_signal") signal glass_broken(position, force)

@warning_ignore("unused_signal") signal time_effect_started(effect_name, intensity)
@warning_ignore("unused_signal") signal time_effect_ended(effect_name)

@warning_ignore("unused_signal") signal batch_started
@warning_ignore("unused_signal") signal batch_complete(quality)
@warning_ignore("unused_signal") signal batch_failed
@warning_ignore("unused_signal") signal meth_batch_collected

@warning_ignore("unused_signal") signal parallax_settings_changed(enabled, strength)
@warning_ignore("unused_signal") signal texture_variation_settings_changed(enabled, strength)
@warning_ignore("unused_signal") signal sprite_smoothing_settings_changed(enabled, quality, preserve_pixels)
@warning_ignore("unused_signal") signal subpixel_animation_settings_changed(enabled, anim_type, anim_speed, anim_amplitude)
@warning_ignore("unused_signal") signal environment_changed(environment_name)
@warning_ignore("unused_signal") signal time_of_day_changed(time)
@warning_ignore("unused_signal") signal resolution_state_changed(state, duration)
@warning_ignore("unused_signal") signal custom_resolution_requested(scale, duration)
@warning_ignore("unused_signal") signal bloom_settings_changed(enabled, intensity, threshold)
@warning_ignore("unused_signal") signal ambient_occlusion_settings_changed(enabled, intensity, radius)
@warning_ignore("unused_signal") signal dithering_settings_changed(enabled, intensity, scale)
@warning_ignore("unused_signal") signal apply_immediate_effect(effect_name, duration)

@warning_ignore("unused_signal") signal money_changed(current_amount)
@warning_ignore("unused_signal") signal business_purchased(business_data)
@warning_ignore("unused_signal") signal business_sold(business_data)
@warning_ignore("unused_signal") signal production_cycle_completed(business_id, product_data)
@warning_ignore("unused_signal") signal territory_changed(territory_id, controlled)
@warning_ignore("unused_signal") signal business_action(action, data)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS