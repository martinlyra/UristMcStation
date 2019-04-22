/*
 *	Urist Edits
 *
 * 2019-04-22 by Irrationalist (Irra)
 *	- Added examine to electric engines for telling whether there is a cell plugged in or not
 *  - Plugging an cell into an electric engine now has a chat message
 *  - Fixed a code error where thermal overrides electrical "putter"
 *  - Refactored thermal's fuel processing into its own proc
 *  - Refactored thermal's fuel checks into several procs
 *  - Added a start-up check proc; "can_turn_on()"
 *  - Added "dead_start()" sound proc for failing start-ups
 *  - Added status checking to 'power_use' and 'can_start_up'
 *
 */

/obj/item/weapon/engine
	name = "engine"
	desc = "An engine used to power a small vehicle."
	icon = 'icons/urist/items/vehicle_parts.dmi'
	w_class = ITEM_SIZE_HUGE
	var/stat = 0
	var/trail_type
	var/cost_per_move = 5

/obj/item/weapon/engine/proc/get_trail()
	if(trail_type)
		return new trail_type
	return null

/obj/item/weapon/engine/proc/prefill()
	return

/obj/item/weapon/engine/proc/use_power()
	return 0

/obj/item/weapon/engine/proc/can_turn_on()
	return 0

/obj/item/weapon/engine/proc/dead_start(var/atom/movable/M, var/mob/user = null)
	return

/obj/item/weapon/engine/proc/rev_engine(var/atom/movable/M, var/mob/user = null)
	return

/obj/item/weapon/engine/proc/putter(var/atom/movable/M, var/mob/user = null)
	return

/obj/item/weapon/engine/electric
	name = "electric engine"
	desc = "A battery-powered engine used to power a small vehicle."
	icon_state = "engine_electric"
	trail_type = /datum/effect/effect/system/trail/ion
	cost_per_move = 200	// W
	var/obj/item/weapon/cell/cell

/obj/item/weapon/engine/electric/attackby(var/obj/item/I, var/mob/user)
	if(istype(I,/obj/item/weapon/cell))
		if(cell)
			to_chat(user, "<span class='warning'>There is already a cell in \the [src].</span>")
		else
			if (user && user.unEquip(I))
				cell = I
				I.forceMove(src)
				to_chat(user, "You insert \the [cell] into \the [src].")
		return 1
	else if(isCrowbar(I))
		if(cell)
			to_chat(user, "You pry out \the [cell].")
			cell.forceMove(get_turf(src))
			cell = null
			return 1
	..()

/obj/item/weapon/engine/electric/prefill()
	cell = new /obj/item/weapon/cell/high(src.loc)

/obj/item/weapon/engine/electric/use_power()
	if(!cell || stat)
		return 0
	return cell.use(cost_per_move * CELLRATE)

/obj/item/weapon/engine/electric/can_turn_on()
	return !stat && cell && cell.check_charge(cost_per_move * CELLRATE)

/obj/item/weapon/engine/electric/dead_start(var/atom/movable/M, var/mob/user)
	if(user)
		to_chat(user, "<i>You try to start the [M], but nothing happens.</i>")

/obj/item/weapon/engine/electric/rev_engine(var/atom/movable/M)
	M.audible_message("\The [M] beeps, spinning up.")

/obj/item/weapon/engine/electric/putter(var/atom/movable/M)
	M.audible_message("\The [M] makes one depressed beep before winding down.")

/obj/item/weapon/engine/electric/emp_act(var/severity)
	if(cell)
		cell.emp_act(severity)
	..()

/obj/item/weapon/engine/electric/examine(mob/user)
	..(user)
	if (cell)
		to_chat(user, "<span class='notice'>This has \a [cell] installed.</span>")
	else
		to_chat(user, "<span class='warning'>This doesn't have a power supply installed.</span>")

/obj/item/weapon/engine/thermal
	name = "thermal engine"
	desc = "A fuel-powered engine used to power a small vehicle."
	icon_state = "engine_fuel"
	trail_type = /datum/effect/effect/system/trail/thermal
	atom_flags = ATOM_FLAG_OPEN_CONTAINER
	var/obj/temp_reagents_holder
	var/fuel_points = 0
	//fuel points are determined by differing reagents

/obj/item/weapon/engine/thermal/prefill()
	fuel_points = 5000

/obj/item/weapon/engine/thermal/New()
	..()
	create_reagents(500)
	temp_reagents_holder = new()
	temp_reagents_holder.create_reagents(15)
	temp_reagents_holder.atom_flags |= ATOM_FLAG_OPEN_CONTAINER

/obj/item/weapon/engine/thermal/attackby(var/obj/item/I, var/mob/user)
	if(istype(I,/obj/item/weapon/reagent_containers) && I.is_open_container())
		if(istype(I,/obj/item/weapon/reagent_containers/food/snacks) || istype(I,/obj/item/weapon/reagent_containers/pill))
			return 0
		var/obj/item/weapon/reagent_containers/C = I
		C.standard_pour_into(user,src)
		return 1
	..()

/obj/item/weapon/engine/thermal/proc/has_fuel_reagents()
	if(!reagents || reagents.total_volume <= 0 || stat)
		return 0
	return 1

/obj/item/weapon/engine/thermal/proc/process_fuel()
	reagents.trans_to(temp_reagents_holder,min(reagents.total_volume,15))

	var/multiplier = 1
	var/actually_flameable = 0

	for(var/datum/reagent/R in temp_reagents_holder.reagents.reagent_list)
		var/new_multiplier = 1
		if(istype(R,/datum/reagent/ethanol))
			var/datum/reagent/ethanol/E = R
			new_multiplier = (10/E.strength)
			actually_flameable = 1
		else if(istype(R,/datum/reagent/hydrazine))
			new_multiplier = 1.25
			actually_flameable = 1
		else if(istype(R,/datum/reagent/fuel))
			actually_flameable = 1
		else if(istype(R,/datum/reagent/toxin/phoron))
			new_multiplier = 2
			actually_flameable = 1
		else if(istype(R,/datum/reagent/frostoil))
			new_multiplier = 0.1
		else if(istype(R,/datum/reagent/water))
			new_multiplier = 0.4
		else if(istype(R,/datum/reagent/sugar)  && R.volume > 1)
			stat = DEAD
			explosion(get_turf(src),-1,0,2,3,0)
			return 0
		multiplier = (multiplier + new_multiplier)/2
	if(!actually_flameable)
		return 0
	fuel_points += 20 * multiplier * temp_reagents_holder.reagents.total_volume
	temp_reagents_holder.reagents.clear_reagents()
	return 1

/obj/item/weapon/engine/thermal/use_power()
	if(stat == DEAD)
		return 0

	if(fuel_points >= cost_per_move)
		fuel_points -= cost_per_move
		return 1

	if (has_fuel_reagents())
		process_fuel()
		return use_power()
	else
		return 0

/obj/item/weapon/engine/thermal/can_turn_on()
	return !stat && ((fuel_points >= cost_per_move) || (has_fuel_reagents() && process_fuel()))

/obj/item/weapon/engine/thermal/dead_start(var/atom/movable/M)
	M.audible_message("\The [M] lets out metallic coughing before going silent.")

/obj/item/weapon/engine/thermal/rev_engine(var/atom/movable/M)
	M.audible_message("\The [M] rumbles to life.")

/obj/item/weapon/engine/thermal/putter(var/atom/movable/M)
	M.audible_message("\The [M] putters before turning off.")