/obj/item/analyzer
	desc = "一种手持式环境扫描仪，可以报告当前的气体水平."
	name = "大气分析仪"
	custom_price = PAYCHECK_LOWER * 0.9
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "analyzer"
	inhand_icon_state = "analyzer"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	obj_flags = CONDUCTS_ELECTRICITY
	item_flags = NOBLUDGEON
	slot_flags = ITEM_SLOT_BELT
	throwforce = 0
	throw_speed = 3
	throw_range = 7
	tool_behaviour = TOOL_ANALYZER
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT * 0.3, /datum/material/glass=SMALL_MATERIAL_AMOUNT * 0.2)
	grind_results = list(/datum/reagent/mercury = 5, /datum/reagent/iron = 5, /datum/reagent/silicon = 5)
	var/cooldown = FALSE
	var/cooldown_time = 250
	var/barometer_accuracy // 0 is the best accuracy.
	var/list/last_gasmix_data

/obj/item/analyzer/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_TOOL_ATOM_ACTED_PRIMARY(tool_behaviour), PROC_REF(on_analyze))

	if(type != /obj/item/analyzer)
		return
	var/static/list/slapcraft_recipe_list = list(/datum/crafting_recipe/material_sniffer)

	AddComponent(
		/datum/component/slapcrafting,\
		slapcraft_recipes = slapcraft_recipe_list,\
	)

/obj/item/analyzer/equipped(mob/user, slot, initial)
	. = ..()
	ADD_TRAIT(user, TRAIT_DETECT_STORM, CLOTHING_TRAIT)

/obj/item/analyzer/dropped(mob/user, silent)
	. = ..()
	REMOVE_TRAIT(user, TRAIT_DETECT_STORM, CLOTHING_TRAIT)

/obj/item/analyzer/examine(mob/user)
	. = ..()
	. += span_notice("右键[src]来打开气体参考.")
	. += span_notice("Alt并单击[src]激活气压计功能.")

/obj/item/analyzer/suicide_act(mob/living/carbon/user)
	user.visible_message(span_suicide("[user]开始用[src]分析自己!屏幕显示其已死亡!"))
	return BRUTELOSS

/obj/item/analyzer/AltClick(mob/user) //Barometer output for measuring when the next storm happens 气压计输出，用于测量下一次风暴何时发生
	..()

	if(!user.can_perform_action(src, NEED_LITERACY|NEED_LIGHT))
		return

	if(cooldown)
		to_chat(user, span_warning("[src]的气压计功能正在准备中."))
		return

	var/turf/T = get_turf(user)
	if(!T)
		return

	playsound(src, 'sound/effects/pop.ogg', 100)
	var/area/user_area = T.loc
	var/datum/weather/ongoing_weather = null

	if(!user_area.outdoors)
		to_chat(user, span_warning("[src]的气压计功能无法在室内使用!"))
		return

	for(var/V in SSweather.processing)
		var/datum/weather/W = V
		if(W.barometer_predictable && (T.z in W.impacted_z_levels) && W.area_type == user_area.type && !(W.stage == END_STAGE))
			ongoing_weather = W
			break

	if(ongoing_weather)
		if((ongoing_weather.stage == MAIN_STAGE) || (ongoing_weather.stage == WIND_DOWN_STAGE))
			to_chat(user, span_warning("[src]的气压计功能无法追踪任何东西当风暴为[ongoing_weather.stage == MAIN_STAGE ? "已经在这了!" : "接近尾声."]"))
			return

		to_chat(user, span_notice("下一次的 [ongoing_weather] 的来袭时间为 [butchertime(ongoing_weather.next_hit_time - world.time)]."))
		if(ongoing_weather.aesthetic)
			to_chat(user, span_warning("[src]'s barometer function says that the next storm will breeze on by."))
	else
		var/next_hit = SSweather.next_hit_by_zlevel["[T.z]"]
		var/fixed = next_hit ? timeleft(next_hit) : -1
		if(fixed < 0)
			to_chat(user, span_warning("[src]'s barometer function was unable to trace any weather patterns."))
		else
			to_chat(user, span_warning("[src]'s barometer function says a storm will land in approximately [butchertime(fixed)]."))
	cooldown = TRUE
	addtimer(CALLBACK(src, TYPE_PROC_REF(/obj/item/analyzer, ping)), cooldown_time)

/obj/item/analyzer/proc/ping()
	if(isliving(loc))
		var/mob/living/L = loc
		to_chat(L, span_notice("[src]的气压计功能准备就绪!"))
	playsound(src, 'sound/machines/click.ogg', 100)
	cooldown = FALSE

/// Applies the barometer inaccuracy to the gas reading.
/obj/item/analyzer/proc/butchertime(amount)
	if(!amount)
		return
	if(barometer_accuracy)
		var/inaccurate = round(barometer_accuracy*(1/3))
		if(prob(50))
			amount -= inaccurate
		if(prob(50))
			amount += inaccurate
	return DisplayTimeText(max(1,amount))

/obj/item/analyzer/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "气体分析仪", "气体分析仪") // gasanlyzer gas anlyzer
		ui.open()

/obj/item/analyzer/ui_static_data(mob/user)
	return return_atmos_handbooks()

/obj/item/analyzer/ui_data(mob/user)
	LAZYINITLIST(last_gasmix_data)
	return list("gasmixes" = last_gasmix_data)

/obj/item/analyzer/attack_self(mob/user, modifiers)
	if(user.stat != CONSCIOUS || !user.can_read(src)) //SKYRAT EDIT: Blind People Can Analyze Again
		return
	atmos_scan(user=user, target=get_turf(src), silent=FALSE)
	on_analyze(source=src, target=get_turf(src))

/obj/item/analyzer/attack_self_secondary(mob/user, modifiers)
	if(user.stat != CONSCIOUS || !user.can_read(src)) //SKYRAT EDIT: Blind People Can Analyze Again
		return

	ui_interact(user)

/// Called when our analyzer is used on something
/obj/item/analyzer/proc/on_analyze(datum/source, atom/target)
	SIGNAL_HANDLER
	var/mixture = target.return_analyzable_air()
	if(!mixture)
		return FALSE
	var/list/airs = islist(mixture) ? mixture : list(mixture)
	var/list/new_gasmix_data = list()
	for(var/datum/gas_mixture/air as anything in airs)
		var/mix_name = capitalize(lowertext(target.name))
		if(airs.len != 1) //not a unary gas mixture
			mix_name += " - Node [airs.Find(air)]"
		new_gasmix_data += list(gas_mixture_parser(air, mix_name))
	last_gasmix_data = new_gasmix_data

/**
 * Outputs a message to the user describing the target's gasmixes.
 *
 * Gets called by analyzer_act, which in turn is called by tool_act.
 * Also used in other chat-based gas scans.
 */
/proc/atmos_scan(mob/user, atom/target, silent=FALSE)
	var/mixture = target.return_analyzable_air()
	if(!mixture)
		return FALSE

	var/icon = target
	var/message = list()
	if(!silent && isliving(user))
		user.visible_message(span_notice("[user] uses the analyzer on [icon2html(icon, viewers(user))] [target]."), span_notice("You use the analyzer on [icon2html(icon, user)] [target]."))
	message += span_boldnotice("Results of analysis of [icon2html(icon, user)] [target].")

	var/list/airs = islist(mixture) ? mixture : list(mixture)
	for(var/datum/gas_mixture/air as anything in airs)
		var/mix_name = capitalize(lowertext(target.name))
		if(airs.len > 1) //not a unary gas mixture
			var/mix_number = airs.Find(air)
			message += span_boldnotice("Node [mix_number]")
			mix_name += " - Node [mix_number]"

		var/total_moles = air.total_moles()
		var/pressure = air.return_pressure()
		var/volume = air.return_volume() //could just do mixture.volume... but safety, I guess?
		var/temperature = air.return_temperature()
		var/heat_capacity = air.heat_capacity()
		var/thermal_energy = air.thermal_energy()

		if(total_moles > 0)
			message += span_notice("摩尔量: [round(total_moles, 0.01)] mol")

			var/list/cached_gases = air.gases
			for(var/id in cached_gases)
				var/gas_concentration = cached_gases[id][MOLES]/total_moles
				message += span_notice("[cached_gases[id][GAS_META][META_GAS_NAME]]: [round(cached_gases[id][MOLES], 0.01)] mol ([round(gas_concentration*100, 0.01)] %)")
			message += span_notice("温度: [round(temperature - T0C,0.01)] &deg;C ([round(temperature, 0.01)] K)")
			message += span_notice("气体体积: [volume] L") // volume
			message += span_notice("压力: [round(pressure, 0.01)] kPa") // pressure
			message += span_notice("热容: [display_joules(heat_capacity)] / K") // heat capacity
			message += span_notice("热能: [display_joules(thermal_energy)]") // Thermal Energy
		else
			message += airs.len > 1 ? span_notice("这个节点是空的!") : span_notice("[target]是空的!")
			message += span_notice("气体体积: [volume] L") // don't want to change the order volume appears in, suck it

	// we let the join apply newlines so we do need handholding
	to_chat(user, examine_block(jointext(message, "\n")), type = MESSAGE_TYPE_INFO)
	return TRUE

/obj/item/analyzer/ranged
	desc = "一种手持式远程环境扫描仪，可以报告当前的气体水平."
	name = "远程气体分析仪"
	icon_state = "analyzerranged"
	worn_icon_state = "analyzer"
	w_class = WEIGHT_CLASS_NORMAL
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 0.2, /datum/material/gold = SMALL_MATERIAL_AMOUNT*3, /datum/material/bluespace=SMALL_MATERIAL_AMOUNT*2)
	grind_results = list(/datum/reagent/mercury = 5, /datum/reagent/iron = 5, /datum/reagent/silicon = 5)

/obj/item/analyzer/ranged/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	if(!can_see(user, target, 15))
		return
	. |= AFTERATTACK_PROCESSED_ITEM
	atmos_scan(user, (target.return_analyzable_air() ? target : get_turf(target)))
