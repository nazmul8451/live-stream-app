import 'package:flutter/material.dart';

/// The 16 AREIS marketplace categories (client spec). Names match the
/// backend seed (category.seed.ts) so they can be sent as interests/filters.
class AreisCategory {
  final String name;
  final String subtitle;
  final IconData icon;
  const AreisCategory(this.name, this.subtitle, this.icon);
}

const List<AreisCategory> areisCategories = [
  AreisCategory('Trading Cards & TCG', 'Sports Cards, Pokémon, MTG', Icons.style_outlined),
  AreisCategory('Sports Memorabilia', 'Jerseys, Autographs, Memorabilia', Icons.emoji_events_outlined),
  AreisCategory('Toys & Collectibles', 'Action Figures, LEGO, Die-Cast, Plush', Icons.toys_outlined),
  AreisCategory('Sneakers & Streetwear', 'Sneakers, Apparel, Streetwear', Icons.directions_run_outlined),
  AreisCategory('Fashion & Apparel', 'Designer Bags, Clothing, More', Icons.checkroom_outlined),
  AreisCategory('Watches & Luxury', 'Watches, Luxury Items', Icons.watch_outlined),
  AreisCategory('Jewelry & Accessories', 'Chains, Rings, Accessories', Icons.diamond_outlined),
  AreisCategory('Electronics & Tech', 'Phones, Tablets, Tech', Icons.devices_other_outlined),
  AreisCategory('Coins & Currency', 'Coins, Currency, Items', Icons.monetization_on_outlined),
  AreisCategory('Comics, Anime & Manga', 'Comics, Manga, Graphic Novels', Icons.menu_book_outlined),
  AreisCategory('Video Games', 'Consoles, Retro Games', Icons.sports_esports_outlined),
  AreisCategory('Vintage & Antiques', 'Vintage Collectibles, Antiques', Icons.history_edu_outlined),
  AreisCategory('Home & Lifestyle', 'Decor, Lifestyle, More', Icons.chair_outlined),
  AreisCategory('Beauty & Personal Care', 'Skincare, Makeup, Fragrance', Icons.spa_outlined),
  AreisCategory('Books, Music & Media', 'Books, Movies, Music, More', Icons.library_music_outlined),
  AreisCategory('Other / Not Listed', 'Miscellaneous Items', Icons.category_outlined),
];

List<String> get areisCategoryNames => areisCategories.map((c) => c.name).toList();
