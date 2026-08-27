import '../core/assets.dart';

class ChickenSkin {
  final String id;
  final String name;
  final String sprite;
  final int price;

  /// Cosmetic skins were drawn facing the opposite way from the default
  /// chicken. When true, gameplay mirrors the sprite so it still looks
  /// toward the direction of travel.
  final bool flipGameplay;

  const ChickenSkin({
    required this.id,
    required this.name,
    required this.sprite,
    required this.price,
    this.flipGameplay = false,
  });
}

const List<ChickenSkin> kChickenSkins = [
  ChickenSkin(id: 'classic', name: 'Classic', sprite: Sprites.chickenMain, price: 0),
  ChickenSkin(id: 'green_scarf', name: 'Meadow Scarf', sprite: Sprites.chickenScarfGreen, price: 400, flipGameplay: true),
  ChickenSkin(id: 'straw_hat', name: 'Straw Hat', sprite: Sprites.chickenHatStraw, price: 600, flipGameplay: true),
  ChickenSkin(id: 'blue_scarf', name: 'River Scarf', sprite: Sprites.chickenScarfBlue, price: 600, flipGameplay: true),
  ChickenSkin(id: 'red_bow', name: 'Ribbon Belle', sprite: Sprites.chickenBowRed, price: 800, flipGameplay: true),
];
