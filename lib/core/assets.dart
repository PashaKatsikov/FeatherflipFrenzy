/// Central registry of every asset path used across the game so that screens
/// and game components never hard-code raw strings.
class Sprites {
  static const _base = 'assets/sprites';

  // Backgrounds / grounds
  static const pastureVista = '$_base/bg_pasture_menu.png';
  static const riverVista = '$_base/bg_river_menu.png';
  static const lakeVista = '$_base/bg_lake_menu.png';
  static const groundPasture = '$_base/ground_pasture.png';

  // Chicken
  static const chickenMain = '$_base/chicken_main.png';
  static const chickenScarfGreen = '$_base/chicken_skin_scarf_green.png';
  static const chickenHatStraw = '$_base/chicken_skin_hat_straw.png';
  static const chickenScarfBlue = '$_base/chicken_skin_scarf_blue.png';
  static const chickenBowRed = '$_base/chicken_skin_bow_red.png';

  // Eggs
  static const eggNormal = '$_base/egg_normal.png';
  static const eggHeavy = '$_base/egg_heavy.png';
  static const eggBouncy = '$_base/egg_bouncy.png';
  static const eggGold = '$_base/egg_gold.png';

  // Nests
  static const nestPlain = '$_base/nest_plain.png';
  static const nestRoped = '$_base/nest_roped.png';
  static const nestFloral = '$_base/nest_floral.png';
  static const nestWheat = '$_base/nest_wheat.png';
  static const nestGolden = '$_base/nest_golden.png';

  // Obstacles / decor
  static const obstacleBush = '$_base/obstacle_bush.png';
  static const obstacleRock = '$_base/obstacle_rock.png';
  static const obstacleStump = '$_base/obstacle_stump.png';
  static const obstacleFence = '$_base/obstacle_fence.png';

  static const plantGrass = '$_base/plant_grass.png';
  static const plantFlowerbush = '$_base/plant_flowerbush.png';
  static const plantWildflowers = '$_base/plant_wildflowers.png';
  static const plantLeafy = '$_base/plant_leafyplant.png';

  static const riverbankReeds = '$_base/riverbank_reeds.png';
  static const riverbankDriftwood = '$_base/riverbank_driftwood.png';
  static const riverbankRocks = '$_base/riverbank_rocks.png';
  static const riverbankPost = '$_base/riverbank_post.png';

  static const treeRound = '$_base/tree_round.png';
  static const treeLayered = '$_base/tree_layered.png';
  static const treeWillow = '$_base/tree_willow.png';
  static const treeFruit = '$_base/tree_fruit.png';

  static const pathStraight = '$_base/path_straight.png';

  static const bridgeSmall = '$_base/bridge_small.png';
  static const bridgeLong = '$_base/bridge_long.png';
  static const bridgeArched = '$_base/bridge_arched.png';

  static const islandSmall = '$_base/island_small.png';
  static const islandMedium = '$_base/island_medium.png';
  static const islandLarge = '$_base/island_large.png';

  static const coop = '$_base/coop.png';
  static const gate = '$_base/gate.png';
  static const haystack = '$_base/haystack.png';
  static const coinIcon = '$_base/coin_icon.png';
  static const coinGoldIcon = '$_base/coin_gold_icon.png';

  static const List<String> preloadList = [
    pastureVista, riverVista, lakeVista, groundPasture,
    chickenMain, chickenScarfGreen, chickenHatStraw, chickenScarfBlue, chickenBowRed,
    eggNormal, eggHeavy, eggBouncy, eggGold,
    nestPlain, nestRoped, nestFloral, nestWheat, nestGolden,
    obstacleBush, obstacleRock, obstacleStump, obstacleFence,
    plantGrass, plantFlowerbush, plantWildflowers, plantLeafy,
    riverbankReeds, riverbankDriftwood, riverbankRocks, riverbankPost,
    treeRound, treeLayered, treeWillow, treeFruit,
    pathStraight,
    bridgeSmall, bridgeLong, bridgeArched,
    islandSmall, islandMedium, islandLarge,
    coop, gate, haystack, coinIcon, coinGoldIcon,
  ];
}

class UiImages {
  static const _base = 'assets/ui';
  static const logo = '$_base/game_logo.png';
  static const loadingHorizontal = '$_base/loading_horizontal.png';
  static const loadingVertical = '$_base/loading_vertical.png';
}

class AppLinks {
  static const privacyPolicy = 'https://featherflipfrenzy.com/privacy-policy.html';
  static const support = 'https://featherflipfrenzy.com/support.html';
}

class Sfx {
  static const _base = 'Featherflip_Frenzy_sounds_assets';
  static const buttonTap = '$_base/button_tap_asset.mp3';
  static const chickenDash = '$_base/chicken_dash_asset.mp3';
  static const chickenEggHit = '$_base/chicken_egg_hit_asset.mp3';
  static const coinCollect = '$_base/coin_collect_asset.mp3';
  static const eggBounce = '$_base/egg_bounce_asset.mp3';
  static const eggDeliverySuccess = '$_base/egg_delivery_success_asset.mp3';
  static const eggWaterSplash = '$_base/egg_water_splash_asset.mp3';
  static const elementSelect = '$_base/element_select_asset.mp3';
  static const menuClose = '$_base/menu_close_asset.mp3';
  static const menuOpen = '$_base/menu_open_asset.mp3';
  static const newZoneUnlock = '$_base/new_zone_unlock_asset.mp3';
  static const rescueDash = '$_base/rescue_dash_asset.mp3';
  static const rewardCollect = '$_base/reward_collect_asset.mp3';
  static const roundComplete = '$_base/round_complete_asset.mp3';
}
