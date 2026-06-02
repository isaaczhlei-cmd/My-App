import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EcoTipSuggestion {
  final String tip;
  final String category;

  const EcoTipSuggestion({required this.tip, required this.category});
}

class EcoTipService {
  @visibleForTesting
  static String debugScrub(String input, String apiKey) {
    if (apiKey.trim().isEmpty) return input;
    return input.replaceAll(apiKey, '[REDACTED]');
  }

  static const String _model = 'gpt-5-mini';
  static const String _baseUrl = 'https://api.openai.com/v1/responses';
  static const List<String> _categories = <String>[
    'travel',
    'home',
    'energy',
    'waste',
    'shopping',
    'general',
  ];

  static const List<EcoTipSuggestion> fallbackTips = <EcoTipSuggestion>[
    EcoTipSuggestion(
      tip:
          'Compare aircraft type and seat count, not just stops, when two fares are similar.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'A slightly longer route can still be cleaner if it uses a newer, denser aircraft.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'If you need a connection, compare hubs because some layovers add a big detour.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'For the same price, pick the itinerary with fewer premium seats or a smaller cabin footprint.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Use flexible dates to unlock a direct flight that is missing on your original day.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'When you must connect, avoid routes that backtrack through a faraway hub.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose nonstop flights when the connection adds more distance than it saves in price.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Check if a nearby airport offers a shorter routing before booking.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Pack lighter so each passenger adds less weight to the flight.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Favor airlines that publish newer, more efficient fleet details.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Avoid tight connections that could force rebooking onto less efficient routes.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Book daytime arrivals when public transit from the airport is still running.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Use carry-on luggage when possible to reduce checked-bag weight.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Compare total travel emissions before choosing a distant alternate airport.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Pick routes with modern narrow-body aircraft for many medium-distance trips.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Bundle meetings into one trip instead of taking several short flights.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Replace short connecting segments with rail when the schedule works.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose economy seats when comfort needs allow; premium cabins carry more emissions.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Compare return dates because one-day flexibility can reveal a cleaner route.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Avoid overnight layovers that require extra hotel shuttles and local trips.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Select airport rail or bus before defaulting to a rideshare pickup.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose direct regional trains over flights for trips under a few hours.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Fly from the airport that creates the shortest total door-to-door route.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Skip unnecessary seat upgrades when your goal is lower trip emissions.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Prefer e-boarding passes to reduce extra paper at check-in.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose lodging near transit so airport transfers stay lower carbon.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Share a ride from the airport when transit is not practical.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Book early enough to compare aircraft, stops, and nearby airport options.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Use one longer stay instead of repeated weekend flights to the same place.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Check train-plus-flight options for routes with short feeder flights.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Avoid itineraries with extra takeoffs when a single flight is available.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Pick flights with higher seat occupancy when reliable estimates are available.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose a cleaner itinerary before buying offsets; reduce first, offset last.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Bring reusable headphones so you can skip disposable airline earbuds.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Carry an empty bottle and refill after security instead of buying plastic water.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Download tickets and maps before departure to avoid printed backups.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose the route with fewer unnecessary miles, not just the shortest layover.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Avoid mileage runs; loyalty points are not worth extra emissions.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Coordinate group travel so fewer separate airport transfers are needed.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose hotels with airport shuttle routes shared by multiple guests.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Compare carbon per passenger when two flight prices are close.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Avoid faraway hubs that turn a simple route into a triangle.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Travel with compact toiletries to reduce luggage weight and waste.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Rent a smaller car at your destination when passenger space allows.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Use airport express buses where rail is unavailable.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Book local meetings near each other to reduce ground transport after landing.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose virtual attendance when a trip has no essential in-person value.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Pack layers instead of extra outfits to keep your bag lighter.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Use a reusable cutlery kit for airport meals and packaged snacks.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Avoid single-use amenity kits when you brought your own essentials.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Select flights that land near your final destination, not just the cheapest city.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose longer connection windows only when they avoid rebooking risk.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Favor routes with efficient aircraft listed on the booking page.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Check whether a code-share uses a cleaner aircraft before selecting it.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Choose ground transport over flights for same-region city pairs.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Skip unnecessary printed receipts at kiosks and rental counters.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Wash clothes during longer trips so you can pack fewer outfits.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Book accommodation with laundry access to make lighter packing practical.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Choose airport pickup spots that do not require long idle queues.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Avoid extra souvenir weight by shipping thoughtfully or buying less.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Compare morning and evening departures because aircraft swaps can change emissions.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Choose flights with fewer empty-positioning risks when airline schedules are stable.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Use one shared itinerary for family trips to reduce duplicate planning emissions.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Prefer local vacations when the flight would be the main source of impact.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'When prices match, pick the lower-carbon itinerary shown in search results.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip:
          'Avoid unnecessary multi-city hops when one destination can cover the trip purpose.',
      category: 'travel',
    ),
    EcoTipSuggestion(
      tip: 'Turn off lights in empty rooms, especially during daylight.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Set the thermostat a little lower in winter and wear a layer.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Set the thermostat a little higher in summer and use fans first.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Wash clothes with cold water when the load is not heavily soiled.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Air-dry clothes when time and space make it practical.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Unplug idle chargers and devices that stay warm when unused.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip:
          'Use smart power strips for entertainment centers and desk equipment.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Clean dryer lint filters so each load dries faster.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Run full dishwasher loads instead of many small cycles.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip:
          'Use the dishwasher air-dry setting when you do not need dishes immediately.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Keep refrigerator coils clean so the compressor works less.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Let hot food cool before putting it in the fridge.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Use lids while cooking to cut stovetop energy use.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Match pot size to burner size to avoid wasted heat.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Batch-cook meals to use the oven fewer times.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Use a toaster oven or microwave for small reheating jobs.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Close curtains on hot afternoons to reduce cooling demand.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Open curtains on sunny winter days for free warmth.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Seal drafty windows and doors before turning up the heat.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Replace burned-out bulbs with LEDs instead of old-style bulbs.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Use task lighting instead of lighting the whole room.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip:
          'Schedule laundry and dishwashing outside local peak energy hours when possible.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Set computers to sleep after short idle periods.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Dim screens when full brightness is not needed.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Clean air filters so heating and cooling systems breathe easier.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip:
          'Use ceiling fans clockwise in winter and counterclockwise in summer.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Keep vents clear of furniture to avoid wasting conditioned air.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Turn off heated dry and sanitize settings unless truly needed.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip:
          'Choose induction or electric cooking when your home uses cleaner electricity.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Use blinds and shade trees to lower cooling loads naturally.',
      category: 'energy',
    ),
    EcoTipSuggestion(
      tip: 'Fix dripping hot-water taps to save both water and energy.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip:
          'Take shorter showers when hot water use is your main household load.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Install low-flow showerheads when old fixtures waste water.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip:
          'Run full laundry loads to use water and detergent more efficiently.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip:
          'Choose concentrated cleaners to reduce packaging and shipping weight.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Repair small leaks quickly before they become daily waste.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Sweep patios and sidewalks instead of hosing them down.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Water plants early in the morning to reduce evaporation.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Use mulch so soil holds moisture longer.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Plant native species that need less watering and fertilizer.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Collect shower warm-up water for plants when practical.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Choose washable cleaning cloths instead of disposable wipes.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Use refillable soap dispensers to reduce bathroom packaging.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Borrow rarely used tools before buying new ones.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Repair appliances when the fix is simple and parts are available.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Donate usable household items instead of throwing them away.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Use washable napkins for everyday meals.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Store leftovers in clear containers so they are eaten first.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Plan meals around food already in your fridge.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Freeze extra bread, fruit, and herbs before they spoil.',
      category: 'home',
    ),
    EcoTipSuggestion(
      tip: 'Compost food scraps where local service or space allows.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Learn your city recycling rules so clean materials avoid landfill.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Rinse containers lightly so recycling loads stay usable.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Skip plastic bags in recycling bins unless your city accepts them.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Keep a small e-waste box for batteries, cables, and old devices.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Choose loose produce when packaging adds no useful protection.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Bring reusable bags for small errands, not only grocery trips.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Carry a reusable cup when you regularly buy drinks out.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Refuse extra utensils and napkins for takeout you eat at home.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Use a shopping list to avoid food that becomes waste.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Eat leftovers as a planned meal, not a backup plan.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Label freezer items with dates so older food gets used first.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Choose reusable food wrap or containers for routine storage.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Repair torn clothing before replacing it.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip:
          'Recycle cardboard after removing plastic tape and packing material.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Use rechargeable batteries for devices you use often.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip:
          'Choose products with replaceable parts instead of sealed disposable designs.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Store produce correctly so it lasts longer.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Use imperfect produce in soups, smoothies, or baked dishes.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Cancel duplicate mailers and catalogs you never read.',
      category: 'waste',
    ),
    EcoTipSuggestion(
      tip: 'Buy durable basics that can handle repeated washing and repair.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Choose secondhand first for furniture, books, and casual clothing.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Wait a day before buying nonessential items online.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Bundle online orders to reduce split shipments and packaging.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Choose slower shipping when you do not need an item urgently.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Compare repairability before buying electronics or appliances.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Pick products with minimal packaging when quality is comparable.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Refill staples from bulk bins when stores nearby offer them.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip:
          'Choose local seasonal produce to reduce storage and transport impact.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Buy only the amount of fresh food you can realistically eat.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Choose plant-forward meals several times a week.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip:
          'Try beans, lentils, or tofu in one meal you normally make with meat.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip:
          'Choose certified refurbished tech when performance needs are modest.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip:
          'Rent special-occasion outfits instead of buying something worn once.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Use library books, tools, and media before buying personal copies.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Choose timeless clothing cuts so pieces stay useful longer.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip:
          'Check care labels before buying clothes that need special cleaning.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Avoid impulse carts by keeping a reusable wishlist.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Pick concentrated detergent to reduce plastic and shipping weight.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip:
          'Choose reusable razors, pens, or filters when refills are available.',
      category: 'shopping',
    ),
    EcoTipSuggestion(
      tip: 'Walk, bike, or transit for errands under a comfortable distance.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Combine errands into one loop instead of separate car trips.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Keep tires properly inflated to improve fuel economy.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Remove roof racks when you are not using them.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Avoid idling while waiting for pickups or curbside orders.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Drive smoothly to reduce fuel use from hard starts and stops.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Carpool for recurring trips when schedules line up.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Use transit for commute days when parking and timing make sense.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Choose video calls for short meetings that would require driving.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Share progress with a friend to make one habit easier to keep.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Track one high-impact habit for a week before adding another.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Start with the repeated choice that creates the most waste or emissions.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Set reusable bags by the door so they leave with you.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Keep a small repair kit where missing buttons and loose screws happen.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Choose digital documents when paper copies are optional.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Decline promotional freebies you do not expect to use.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Share rarely used items with neighbors before everyone buys their own.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Pick one reusable item for the disposable thing you use most.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Choose tap water over bottled water when local water is safe.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Keep a reusable container in your bag for leftovers.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Use a calendar reminder for monthly filter, tire, and leak checks.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Choose community repair events for items you are unsure how to fix.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Ask restaurants to skip extras you will not use.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Prefer durable glass or metal containers for food you store often.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Use navigation to avoid stop-and-go traffic when driving is necessary.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Choose local recreation when the travel impact would outweigh the activity.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Replace one disposable subscription item with a refillable version.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Keep donation boxes visible so usable items leave your home cleanly.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Use shared workspaces or libraries when they prevent extra heating at home.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Choose experiences as gifts when physical items may go unused.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Plan weekly meals before shopping so ingredients have a job.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Keep a visible leftovers shelf so food gets eaten soon.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Use tap-to-pay receipts digitally when stores offer the option.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Choose refill stations for water during errands and workouts.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Measure detergent instead of guessing; extra soap adds waste.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Use the smallest practical trash bag to notice avoidable waste sooner.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Check expiration dates before shopping so older items get used first.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Choose manual tools for quick jobs instead of powering up larger appliances.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Share extra garden harvests before they spoil.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Choose a nearby pickup location if it reduces failed deliveries.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Group returns into one trip or shipment when returns are unavoidable.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip: 'Store reusable items where the disposable alternative used to be.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Set a household default to repair, borrow, or buy used before buying new.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Choose lower-impact habits you can repeat daily over rare dramatic changes.',
      category: 'general',
    ),
    EcoTipSuggestion(
      tip:
          'Review your highest-emission category monthly and make one targeted change.',
      category: 'general',
    ),
  ];

  final http.Client _client;
  final String? _apiKeyOverride;
  final bool _ownsClient;

  EcoTipService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKeyOverride = apiKey,
      _ownsClient = client == null;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<EcoTipSuggestion> fetchEcoTip({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
    int refreshToken = 0,
  }) async {
    final apiKey = _apiKeyOverride ?? dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.trim().isEmpty) {
      return pickFallbackTip(
        flightCount: flightCount,
        totalEmissionsKg: totalEmissionsKg,
        recentTravelPattern: recentTravelPattern,
        refreshToken: refreshToken,
      );
    }

    final requestBody = _buildRequestBody(
      flightCount: flightCount,
      totalEmissionsKg: totalEmissionsKg,
      recentTravelPattern: recentTravelPattern,
      refreshToken: refreshToken,
    );

    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final outputText = _extractOutputText(decoded)?.trim();
      if (outputText == null || outputText.isEmpty) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final parsed = jsonDecode(outputText);
      if (parsed is! Map<String, dynamic>) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final tip = (parsed['tip'] as String?)?.trim();
      if (tip == null || tip.isEmpty) {
        return pickFallbackTip(
          flightCount: flightCount,
          totalEmissionsKg: totalEmissionsKg,
          recentTravelPattern: recentTravelPattern,
          refreshToken: refreshToken,
        );
      }

      final category = _normalizeCategory(parsed['category'] as String?);
      return EcoTipSuggestion(tip: tip, category: category);
    } catch (_) {
      return pickFallbackTip(
        flightCount: flightCount,
        totalEmissionsKg: totalEmissionsKg,
        recentTravelPattern: recentTravelPattern,
        refreshToken: refreshToken,
      );
    }
  }

  static EcoTipSuggestion pickFallbackTip({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
    int refreshToken = 0,
  }) {
    final seed =
        flightCount * 7 +
        totalEmissionsKg.round() +
        recentTravelPattern.runes.fold<int>(0, (sum, rune) => sum + rune) +
        refreshToken * 13;
    final index = seed.abs() % fallbackTips.length;
    return fallbackTips[index];
  }

  Map<String, dynamic> _buildRequestBody({
    required int flightCount,
    required double totalEmissionsKg,
    required String recentTravelPattern,
    required int refreshToken,
  }) {
    return {
      'model': _model,
      'input': [
        {
          'role': 'system',
          'content': [
            {
              'type': 'input_text',
              'text':
                  'You write one short, practical eco tip for a flight carbon tracker app. '
                  'Focus on real flight-planning tradeoffs like aircraft type, cabin layout, connection hubs, '
                  'seat density, route detours, and flexible dates. '
                  'Do not give generic sustainability advice or obvious tips unless they are directly justified by the trip. '
                  'Prefer concrete, less-obvious, real-world guidance that helps the user choose a better itinerary. '
                  'Return only JSON that matches the schema. Keep the tip to one sentence and under 18 words.',
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text':
                  '''
User context:
- Flight count: $flightCount
- Total emissions: ${totalEmissionsKg.toStringAsFixed(1)} kg CO2
- Recent travel pattern: $recentTravelPattern
- Refresh token: $refreshToken

Write one tailored eco tip that helps the user choose a better flight itinerary.
''',
            },
          ],
        },
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'eco_tip',
          'strict': true,
          'description': 'A single short eco tip for the homescreen.',
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'tip': {'type': 'string', 'minLength': 1},
              'category': {'type': 'string', 'enum': _categories},
            },
            'required': ['tip'],
          },
        },
      },
      'max_output_tokens': 80,
    };
  }

  String? _extractOutputText(Map<String, dynamic> decoded) {
    final direct = decoded['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }

    final output = decoded['output'];
    if (output is! List) {
      return null;
    }

    final buffer = StringBuffer();
    for (final item in output) {
      if (item is! Map<String, dynamic>) continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is! Map<String, dynamic>) continue;
        if (part['type'] == 'output_text' && part['text'] is String) {
          buffer.write(part['text'] as String);
        }
      }
    }

    final extracted = buffer.toString();
    return extracted.isEmpty ? null : extracted;
  }

  String _normalizeCategory(String? category) {
    final normalized = (category ?? 'general').trim().toLowerCase();
    if (_categories.contains(normalized)) {
      return normalized;
    }
    return 'general';
  }
}
