/obj/item/radio/intercom //ICON OVERRIDEN IN SKYRAT AESTHETICS - SEE MODULE
	name = "无线电台"
	desc = "一个值得信赖的无线电电台,在没有耳机的情况下也能够投入使用."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "intercom"
	anchored = TRUE
	w_class = WEIGHT_CLASS_BULKY
	canhear_range = 2
	dog_fashion = null
	unscrewed = FALSE
	item_flags = NO_BLOOD_ON_ITEM

	overlay_speaker_idle = "intercom_s"
	overlay_speaker_active = "intercom_recieve"

	overlay_mic_idle = "intercom_m"
	overlay_mic_active = null

	///The icon of intercom while its turned off
	var/icon_off = "intercom-p"

/obj/item/radio/intercom/unscrewed
	unscrewed = TRUE

/obj/item/radio/intercom/prison
	name = "收音机"
	desc = "原本是个对讲机，不过已经被改造成只能收音了."
	icon_state = "intercom_prison"
	icon_off = "intercom_prison-p"

/obj/item/radio/intercom/prison/Initialize(mapload, ndir, building)
	. = ..()
	wires?.cut(WIRE_TX)

/obj/item/radio/intercom/Initialize(mapload, ndir, building)
	. = ..()
	var/area/current_area = get_area(src)
	if(!current_area)
		return
	RegisterSignal(current_area, COMSIG_AREA_POWER_CHANGE, PROC_REF(AreaPowerCheck))
	GLOB.intercoms_list += src
	if(!unscrewed)
		find_and_hang_on_wall(directional = TRUE, \
			custom_drop_callback = CALLBACK(src, PROC_REF(knock_down)))

/obj/item/radio/intercom/Destroy()
	. = ..()
	GLOB.intercoms_list -= src

/obj/item/radio/intercom/examine(mob/user)
	. = ..()
	. += span_notice("使用[MODE_TOKEN_INTERCOM]时，需在附近的时候对着它说话.")
	if(!unscrewed)
		. += span_notice("它是用<b>螺丝钉<b>固定在墙上的.")
	else
		. += span_notice("它的<b>螺丝钉<b>已经松了，可以被取下来.")

	if(anonymize)
		. += span_notice("如果你通过这个无线电说话，别人将认不出你的声音.")

	if(freqlock == RADIO_FREQENCY_UNLOCKED)
		if(obj_flags & EMAGGED)
			. += span_warning("它的频率锁被短路了...")
	else
		. += span_notice("它的频率被锁定在[frequency/10].")

/obj/item/radio/intercom/screwdriver_act(mob/living/user, obj/item/tool)
	if(unscrewed)
		user.visible_message(span_notice("[user]开始拧紧[src]的螺丝..."), span_notice("你开始拧紧[src]的螺丝..."))
		if(tool.use_tool(src, user, 30, volume=50))
			user.visible_message(span_notice("[user]拧紧了[src]的螺丝!"), span_notice("你拧紧了[src]的螺丝."))
			unscrewed = FALSE
	else
		user.visible_message(span_notice("[user]开始拧开[src]的螺丝..."), span_notice("你开始拧开[src]的螺丝..."))
		if(tool.use_tool(src, user, 40, volume=50))
			user.visible_message(span_notice("[user]拧开了[src]的螺丝!"), span_notice("你拧开了[src]的螺丝."))
			unscrewed = TRUE
	return TRUE

/obj/item/radio/intercom/wrench_act(mob/living/user, obj/item/tool)
	. = TRUE
	if(!unscrewed)
		to_chat(user, span_warning("你得先拧开[src]的螺丝!"))
		return
	user.visible_message(span_notice("[user]开始拆下[src]..."), span_notice("你开始拆下[src]..."))
	tool.play_tool_sound(src)
	if(tool.use_tool(src, user, 80))
		user.visible_message(span_notice("[user]拆下了[src]!"), span_notice("你把[src]从墙上拆下来了."))
		playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
		knock_down()

/**
 * Override attack_tk_grab instead of attack_tk because we actually want attack_tk's
 * functionality. What we DON'T want is attack_tk_grab attempting to pick up the
 * intercom as if it was an ordinary item.
 */
/obj/item/radio/intercom/attack_tk_grab(mob/user)
	interact(user)
	return COMPONENT_CANCEL_ATTACK_CHAIN


/obj/item/radio/intercom/attack_ai(mob/user)
	interact(user)

/obj/item/radio/intercom/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return
	interact(user)

/obj/item/radio/intercom/ui_state(mob/user)
	return GLOB.default_state

/obj/item/radio/intercom/can_receive(freq, list/levels)
	if(levels != RADIO_NO_Z_LEVEL_RESTRICTION)
		var/turf/position = get_turf(src)
		if(isnull(position) || !(position.z in levels))
			return FALSE

	if(freq == FREQ_SYNDICATE)
		if(!(syndie))
			return FALSE//Prevents broadcast of messages over devices lacking the encryption

	return TRUE

/obj/item/radio/intercom/Hear(message, atom/movable/speaker, message_langs, raw_message, radio_freq, list/spans, list/message_mods = list(), message_range)
	if(message_mods[RADIO_EXTENSION] == MODE_INTERCOM)
		return  // Avoid hearing the same thing twice
	return ..()

/obj/item/radio/intercom/emp_act(severity)
	. = ..() // Parent call here will set `on` to FALSE.
	update_appearance()

/obj/item/radio/intercom/end_emp_effect(curremp)
	. = ..()
	AreaPowerCheck() // Make sure the area/local APC is powered first before we actually turn back on.

/obj/item/radio/intercom/emag_act(mob/user, obj/item/card/emag/emag_card)
	. = ..()

	if(obj_flags & EMAGGED)
		return

	switch(freqlock)
		// Emagging an intercom with an emaggable lock will remove the lock
		if(RADIO_FREQENCY_EMAGGABLE_LOCK)
			balloon_alert(user, "频率锁已清除")
			playsound(src, SFX_SPARKS, 75, TRUE, SILENCED_SOUND_EXTRARANGE)
			freqlock = RADIO_FREQENCY_UNLOCKED
			obj_flags |= EMAGGED
			return TRUE

		// A fully locked one will do nothing, as locked is intended to be used for stuff that should never be changed
		if(RADIO_FREQENCY_LOCKED)
			balloon_alert(user, "不可覆写该频率锁")
			playsound(src, 'sound/machines/buzz-two.ogg', 50, FALSE, SILENCED_SOUND_EXTRARANGE)
			return

		// Emagging an unlocked one will do nothing, for now
		else
			return

/obj/item/radio/intercom/update_icon_state()
	icon_state = on ? initial(icon_state) : icon_off
	return ..()

/**
 * Proc called whenever the intercom's area loses or gains power. Responsible for setting the `on` variable and calling `update_icon()`.
 *
 * Normally called after the intercom's area recieves the `COMSIG_AREA_POWER_CHANGE` signal, but it can also be called directly.
 * Arguments:
 * * source - the area that just had a power change.
 */
/obj/item/radio/intercom/proc/AreaPowerCheck(datum/source)
	SIGNAL_HANDLER
	var/area/current_area = get_area(src)
	if(!current_area)
		set_on(FALSE)
	else
		set_on(current_area.powered(AREA_USAGE_EQUIP)) // set "on" to the equipment power status of our area.
	update_appearance()

/**
 * Called by the wall mount component and reused during the tool deconstruction proc.
 */
/obj/item/radio/intercom/proc/knock_down()
	new/obj/item/wallframe/intercom(get_turf(src))
	qdel(src)

//Created through the autolathe or through deconstructing intercoms. Can be applied to wall to make a new intercom on it!
/obj/item/wallframe/intercom
	name = "无线电台"
	desc = "一个随时可用的无线电台,把它贴在墙上,然后拧紧螺丝!"
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "intercom"
	result_path = /obj/item/radio/intercom/unscrewed
	pixel_shift = 26
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 0.75, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 0.25)

MAPPING_DIRECTIONAL_HELPERS(/obj/item/radio/intercom, 27)

/obj/item/radio/intercom/chapel
	name = "忏悔对讲机"
	desc = "对它说话...承认你的罪过，它会隐藏你的身份，好让你继续保守秘密."
	anonymize = TRUE
	freqlock = RADIO_FREQENCY_EMAGGABLE_LOCK

/obj/item/radio/intercom/chapel/Initialize(mapload, ndir, building)
	. = ..()
	set_frequency(1481)
	set_broadcasting(TRUE)

/obj/item/radio/intercom/command
	name = "指挥部无线电台"
	desc = "指挥部专用的自由频率无线电台，它是一个多功能的电台，可以调到任何频率，并允许你访问你不应该在的频道。此外，它还配备了一个内置的语音放大器，用于实现水晶般清晰的通讯."
	icon_state = "intercom_command"
	freerange = TRUE
	command = TRUE
	icon_off = "intercom_command-p"

MAPPING_DIRECTIONAL_HELPERS(/obj/item/radio/intercom/prison, 27)
MAPPING_DIRECTIONAL_HELPERS(/obj/item/radio/intercom/chapel, 27)
MAPPING_DIRECTIONAL_HELPERS(/obj/item/radio/intercom/command, 27)
