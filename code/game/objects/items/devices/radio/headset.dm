// Used for translating channels to tokens on examination
GLOBAL_LIST_INIT(channel_tokens, list(
	RADIO_CHANNEL_COMMON = RADIO_KEY_COMMON,
	RADIO_CHANNEL_SCIENCE = RADIO_TOKEN_SCIENCE,
	RADIO_CHANNEL_COMMAND = RADIO_TOKEN_COMMAND,
	RADIO_CHANNEL_MEDICAL = RADIO_TOKEN_MEDICAL,
	RADIO_CHANNEL_ENGINEERING = RADIO_TOKEN_ENGINEERING,
	RADIO_CHANNEL_SECURITY = RADIO_TOKEN_SECURITY,
	RADIO_CHANNEL_CENTCOM = RADIO_TOKEN_CENTCOM,
	RADIO_CHANNEL_FACTION = RADIO_TOKEN_FACTION, //SKYRAT EDIT ADDITION - Faction
	RADIO_CHANNEL_CYBERSUN = RADIO_TOKEN_CYBERSUN, //SKYRAT EDIT ADDITION - Mapping
	RADIO_CHANNEL_INTERDYNE = RADIO_TOKEN_INTERDYNE, //SKYRAT EDIT ADDITION - Mapping
	RADIO_CHANNEL_GUILD = RADIO_TOKEN_GUILD, //SKYRAT EDIT ADDITION - Mapping
	RADIO_CHANNEL_TARKON = RADIO_TOKEN_TARKON, //SKYRAT EDIT ADDITION - MAPPING
	RADIO_CHANNEL_SOLFED = RADIO_TOKEN_SOLFED, //SKYRAT EDIT ADDITION - SOLFED
	RADIO_CHANNEL_SYNDICATE = RADIO_TOKEN_SYNDICATE,
	RADIO_CHANNEL_SUPPLY = RADIO_TOKEN_SUPPLY,
	RADIO_CHANNEL_SERVICE = RADIO_TOKEN_SERVICE,
	MODE_BINARY = MODE_TOKEN_BINARY,
	RADIO_CHANNEL_AI_PRIVATE = RADIO_TOKEN_AI_PRIVATE
))

/obj/item/radio/headset
	name = "无线电耳机"
	desc = "本质上是可以带在头上的对讲机，插入对应的密钥以解锁对应的通话频道。"
	icon = 'icons/obj/clothing/headsets.dmi'
	icon_state = "headset"
	inhand_icon_state = "headset"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	worn_icon_state = "headset"
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT * 0.75)
	subspace_transmission = TRUE
	canhear_range = 0 // can't hear headsets from very far away

	slot_flags = ITEM_SLOT_EARS
	dog_fashion = null
	var/obj/item/encryptionkey/keyslot2 = null
	/// A list of all languages that this headset allows the user to understand. Populated by language encryption keys.
	var/list/language_list

	// headset is too small to display overlays
	overlay_speaker_idle = null
	overlay_speaker_active = null
	overlay_mic_idle = null
	overlay_mic_active = null

/obj/item/radio/headset/suicide_act(mob/living/carbon/user)
	user.visible_message(span_suicide("[user] begins putting \the [src]'s antenna up [user.p_their()] nose! It looks like [user.p_theyre()] trying to give [user.p_them()]self cancer!"))
	return TOXLOSS

/obj/item/radio/headset/examine(mob/user)
	. = ..()

	if(item_flags & IN_INVENTORY && loc == user)
		// construction of frequency description
		var/list/avail_chans = list("使用[RADIO_KEY_COMMON]为当前的信号频率")
		if(translate_binary)
			avail_chans += "use [MODE_TOKEN_BINARY] for [MODE_BINARY]"
		if(length(channels))
			for(var/i in 1 to length(channels))
				if(i == 1)
					avail_chans += "use [MODE_TOKEN_DEPARTMENT] or [GLOB.channel_tokens[channels[i]]] for [lowertext(channels[i])]"
				else
					avail_chans += "use [GLOB.channel_tokens[channels[i]]] for [lowertext(channels[i])]"
		. += span_notice("耳机上的一个小屏幕显示了以下可用频率:\n[english_list(avail_chans)].")
//chiese_list??
		if(command)
			. += span_info("按Alt并单击以切换到高音量模式.")
	else
		. += span_notice("耳机上的一个小屏幕在闪烁，它太小了，如果不拿在手里或戴着耳机就无法看清。")

/obj/item/radio/headset/Initialize(mapload)
	. = ..()
	if(ispath(keyslot2))
		keyslot2 = new keyslot2()
	set_listening(TRUE)
	recalculateChannels()
	possibly_deactivate_in_loc()

/obj/item/radio/headset/proc/possibly_deactivate_in_loc()
	if(ismob(loc))
		set_listening(should_be_listening)
	else
		set_listening(FALSE, actual_setting = FALSE)

/obj/item/radio/headset/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	possibly_deactivate_in_loc()

/obj/item/radio/headset/Destroy()
	if(istype(keyslot2))
		QDEL_NULL(keyslot2)
	return ..()

/obj/item/radio/headset/ui_data(mob/user)
	. = ..()
	.["headset"] = TRUE

/obj/item/radio/headset/MouseDrop(mob/over, src_location, over_location)
	var/mob/headset_user = usr
	if((headset_user == over) && headset_user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return attack_self(headset_user)
	return ..()

/// Grants all the languages this headset allows the mob to understand via installed chips.
/obj/item/radio/headset/proc/grant_headset_languages(mob/grant_to)
	for(var/language in language_list)
		grant_to.grant_language(language, language_flags = UNDERSTOOD_LANGUAGE, source = LANGUAGE_RADIOKEY)

/obj/item/radio/headset/equipped(mob/user, slot, initial)
	. = ..()
	if(!(slot_flags & slot))
		return

	grant_headset_languages(user)

/obj/item/radio/headset/dropped(mob/user, silent)
	. = ..()
	for(var/language in language_list)
		user.remove_language(language, language_flags = UNDERSTOOD_LANGUAGE, source = LANGUAGE_RADIOKEY)

/obj/item/radio/headset/syndicate //disguised to look like a normal headset for stealth ops

/obj/item/radio/headset/syndicate/Initialize(mapload)
	. = ..()
	make_syndie()

/obj/item/radio/headset/syndicate/alt //undisguised bowman with flash protection
	name = "辛迪加无线电耳机"
	desc = "一个可以听到所有无线电频率的耳机，并保护耳朵不受闪光弹的伤害."
	icon_state = "syndie_headset"
	worn_icon_state = "syndie_headset"

/obj/item/radio/headset/syndicate/alt/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection, list(ITEM_SLOT_EARS))

/obj/item/radio/headset/syndicate/alt/leader
	name = "队长耳机"
	command = TRUE

/obj/item/radio/headset/binary
	keyslot = /obj/item/encryptionkey/binary

/obj/item/radio/headset/headset_sec
	name = "安保无线电耳机"
	desc = "被你们的精锐安保部队使用."
	icon_state = "sec_headset"
	worn_icon_state = "sec_headset"
	keyslot = /obj/item/encryptionkey/headset_sec

/obj/item/radio/headset/headset_sec/alt
	name = "安保头戴式耳机"
	desc = "被你们的精锐安保部队使用，保护耳朵不受闪光弹的伤害."
	icon_state = "sec_headset_alt"
	worn_icon_state = "sec_headset_alt"

/obj/item/radio/headset/headset_sec/alt/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection, list(ITEM_SLOT_EARS))

/obj/item/radio/headset/headset_eng
	name = "工程无线电耳机"
	desc = "当工程师们希望像女孩一样聊天的时候."
	icon_state = "eng_headset"
	worn_icon_state = "eng_headset"
	keyslot = /obj/item/encryptionkey/headset_eng

/obj/item/radio/headset/headset_rob
	name = "机器人无线电耳机"
	desc = "专门为机器人专家制作的."
	icon_state = "rob_headset"
	worn_icon_state = "rob_headset"
	keyslot = /obj/item/encryptionkey/headset_rob

/obj/item/radio/headset/headset_med
	name = "医疗无线电耳机"
	desc = "训练有素的医生们的耳机."
	icon_state = "med_headset"
	worn_icon_state = "med_headset"
	keyslot = /obj/item/encryptionkey/headset_med

/obj/item/radio/headset/headset_sci
	name = "科研无线电耳机"
	desc = "科研部门的耳机."
	icon_state = "sci_headset"
	worn_icon_state = "sci_headset"
	keyslot = /obj/item/encryptionkey/headset_sci

/obj/item/radio/headset/headset_medsci
	name = "医学研究无线电耳机"
	desc = "这款耳机是医学和科学结合的产物."
	icon_state = "medsci_headset"
	worn_icon_state = "medsci_headset"
	keyslot = /obj/item/encryptionkey/headset_medsci

/obj/item/radio/headset/headset_srvsec
	name = "法务无线电耳机"
	desc = "在法务耳机中，加密密钥接通两个独立但同等重要的部门，一个是Sec负责调查犯罪，一个是Service负责提供服务，这些是他们的通讯。"
	icon_state = "srvsec_headset"
	worn_icon_state = "srvsec_headset"
	keyslot = /obj/item/encryptionkey/headset_srvsec

/obj/item/radio/headset/headset_srvmed
	name = "服务医疗无线电耳机"
	desc = "允许佩戴者与医疗部和服务部进行通信."
	icon_state = "srv_headset"
	worn_icon_state = "srv_headset"
	keyslot = /obj/item/encryptionkey/headset_srvmed

/obj/item/radio/headset/headset_com
	name = "指挥无线电耳机"
	desc = "接通指挥频道的无线电耳机."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/headset_com

/obj/item/radio/headset/heads
	command = TRUE

/obj/item/radio/headset/heads/captain
	name = "\proper 舰长的耳机"
	desc = "为空间站的王而打造的耳机."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/captain

/obj/item/radio/headset/heads/captain/alt
	name = "\proper 舰长的战术耳机"
	desc = "空间站老大的耳机，具有保护听觉的功能."
	icon_state = "com_headset_alt"
	worn_icon_state = "com_headset_alt"

/obj/item/radio/headset/heads/captain/alt/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection, list(ITEM_SLOT_EARS))

/obj/item/radio/headset/heads/rd
	name = "\proper 研究主管的耳机"
	desc = "佩戴者使社会向着技术奇点前进."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/rd

/obj/item/radio/headset/heads/hos
	name = "\proper 安保部长的耳机"
	desc = "负责维持秩序和保护空间站的人戴的耳机."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/hos

/obj/item/radio/headset/heads/hos/alt
	name = "\proper 安保部长的战术耳机"
	desc = "负责维持秩序和保护空间站的人戴的耳机.对听觉有保护作用."
	icon_state = "com_headset_alt"
	worn_icon_state = "com_headset_alt"

/obj/item/radio/headset/heads/hos/alt/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection, list(ITEM_SLOT_EARS))

/obj/item/radio/headset/heads/ce
	name = "\proper 工程部长的耳机"
	desc = "负责保证空间站正常运转的人的耳机."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/ce

/obj/item/radio/headset/heads/cmo
	name = "\proper 医疗部长的耳机"
	desc = "训练有素的医疗主任的耳机."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/cmo

/obj/item/radio/headset/heads/hop
	name = "\proper 人事部长的耳机"
	desc = "有一天会成为船长的人的耳机."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/hop

/obj/item/radio/headset/heads/qm
	name = "\proper 军需官的耳机"
	desc = "军火之王的耳机."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/qm

/obj/item/radio/headset/headset_cargo
	name = "补给无线电耳机"
	desc = "给军需官的奴隶们带的耳机."
	icon_state = "cargo_headset"
	worn_icon_state = "cargo_headset"
	keyslot = /obj/item/encryptionkey/headset_cargo

/obj/item/radio/headset/headset_cargo/mining
	name = "矿工无线电耳机"
	desc = "被竖井矿工所佩戴的耳机."
	icon_state = "mine_headset"
	worn_icon_state = "mine_headset"
	// "puts the antenna down" while the headset is off
	overlay_speaker_idle = "headset_up"
	overlay_mic_idle = "headset_up"
	keyslot = /obj/item/encryptionkey/headset_mining

/obj/item/radio/headset/headset_srv
	name = "服务无线电耳机"
	desc = "由服务人员使用，其任务是保持站点的完整、愉快和清洁."
	icon_state = "srv_headset"
	worn_icon_state = "srv_headset"
	keyslot = /obj/item/encryptionkey/headset_service

/obj/item/radio/headset/headset_cent
	name = "\improper 中央指挥部无线电耳机"
	desc = "接通纳米高层."
	icon_state = "cent_headset"
	worn_icon_state = "cent_headset"
	keyslot = /obj/item/encryptionkey/headset_cent
	keyslot2 = /obj/item/encryptionkey/headset_com

/obj/item/radio/headset/headset_cent/empty
	keyslot = null
	keyslot2 = null

/obj/item/radio/headset/headset_cent/commander
	keyslot2 = /obj/item/encryptionkey/heads/captain

/obj/item/radio/headset/headset_cent/alt
	name = "\improper 中央指挥部无线电耳机"
	desc = "被应急响应部队使用.对听力有保护功能."
	icon_state = "cent_headset_alt"
	worn_icon_state = "cent_headset_alt"
	keyslot2 = null

/obj/item/radio/headset/headset_cent/alt/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/earprotection, list(ITEM_SLOT_EARS))

/obj/item/radio/headset/silicon/pai
	name = "\proper 迷你集成子空间收发器 "
	subspace_transmission = FALSE


/obj/item/radio/headset/silicon/ai
	name = "\proper 集成子空间收发器 "
	keyslot2 = new /obj/item/encryptionkey/ai
	command = TRUE

/obj/item/radio/headset/silicon/ai/evil
	name = "\proper EVIL集成子空间收发器 "
	keyslot2 = new /obj/item/encryptionkey/ai/evil
	command = FALSE

/obj/item/radio/headset/silicon/ai/evil/Initialize(mapload)
	. = ..()
	make_syndie()

/obj/item/radio/headset/screwdriver_act(mob/living/user, obj/item/tool)
	if(keyslot || keyslot2)
		for(var/ch_name in channels)
			SSradio.remove_object(src, GLOB.radiochannels[ch_name])
			secure_radio_connections[ch_name] = null

		if(keyslot)
			user.put_in_hands(keyslot)
			keyslot = null
		if(keyslot2)
			user.put_in_hands(keyslot2)
			keyslot2 = null

		recalculateChannels()
		to_chat(user, span_notice("你拿出耳机里的加密密钥."))

	else
		to_chat(user, span_warning("这耳机没有任何特殊的加密密钥! 真没用..."))
	tool.play_tool_sound(src, 10)
	return TRUE

/obj/item/radio/headset/attackby(obj/item/W, mob/user, params)
	user.set_machine(src)

	if(istype(W, /obj/item/encryptionkey))
		if(keyslot && keyslot2)
			to_chat(user, span_warning("这耳机装不下更多密钥了!"))
			return

		if(!keyslot)
			if(!user.transferItemToLoc(W, src))
				return
			keyslot = W

		else
			if(!user.transferItemToLoc(W, src))
				return
			keyslot2 = W


		recalculateChannels()
	else
		return ..()

/obj/item/radio/headset/recalculateChannels()
	. = ..()
	if(keyslot2)
		for(var/ch_name in keyslot2.channels)
			if(!(ch_name in src.channels))
				LAZYSET(channels, ch_name, keyslot2.channels[ch_name])

		if(keyslot2.translate_binary)
			translate_binary = TRUE
		if(keyslot2.syndie)
			syndie = TRUE
		if(keyslot2.independent)
			independent = TRUE

		for(var/ch_name in channels)
			secure_radio_connections[ch_name] = add_radio(src, GLOB.radiochannels[ch_name])

	var/list/old_language_list = language_list?.Copy()
	language_list = list()
	if(keyslot?.translated_language)
		language_list += keyslot.translated_language
	if(keyslot2?.translated_language)
		language_list += keyslot2.translated_language

	// If we're equipped on a mob, we should make sure all the languages
	// learned from our installed key chips are all still accurate
	var/mob/mob_loc = loc
	if(istype(mob_loc) && mob_loc.get_item_by_slot(slot_flags) == src)
		// Remove all the languages we may not be able to know anymore
		for(var/language in old_language_list)
			mob_loc.remove_language(language, language_flags = UNDERSTOOD_LANGUAGE, source = LANGUAGE_RADIOKEY)

		// And grant all the languages we definitely should know now
		grant_headset_languages(mob_loc)

/obj/item/radio/headset/AltClick(mob/living/user)
	if(!istype(user) || !Adjacent(user) || user.incapacitated())
		return
	if (command)
		use_command = !use_command
		to_chat(user, span_notice("你切换高音模式 [use_command ? "on" : "off"]."))
