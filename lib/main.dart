import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// POKÉDEX NOIR — Dark editorial redesign. Only dependency: http.
const bg = Color(0xFF0B1020);
const panel = Color(0xFF151D30);
const panel2 = Color(0xFF1B263B);
const white = Color(0xFFF7F9FF);
const dim = Color(0xFF93A1B9);
const accent = Color(0xFFB9F16C);

String cap(String s) => s.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
String tag(int n) => '#${n.toString().padLeft(4, '0')}';
int urlId(String url) => int.tryParse(Uri.parse(url).pathSegments.where((e) => e.isNotEmpty).last) ?? 0;
String art(int id, {bool shiny = false}) => shiny
    ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/shiny/$id.png'
    : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';
Color typeColor(String t) => <String, Color>{
  'fire': const Color(0xFFFF8A65), 'water': const Color(0xFF6BA9FF),
  'grass': const Color(0xFF74D8A7), 'electric': const Color(0xFFFFD76D),
  'poison': const Color(0xFFB98CFA), 'psychic': const Color(0xFFFF83AC),
  'flying': const Color(0xFF92B3EC), 'normal': const Color(0xFFB5B8C9),
  'fighting': const Color(0xFFEB8C72), 'ground': const Color(0xFFE4BD7A),
  'rock': const Color(0xFFCFBB8B), 'bug': const Color(0xFFAFCD70),
  'ghost': const Color(0xFF9792E9), 'steel': const Color(0xFF9FBBCB),
  'ice': const Color(0xFF8CDDE2), 'dragon': const Color(0xFF8D8CF6),
}[t] ?? accent;

class Api {
  static const root = 'https://pokeapi.co/api/v2';
  final http.Client client = http.Client();
  final Map<String, Map<String, dynamic>> cache = {};
  Future<Map<String, dynamic>> get(String url) async {
    if (cache.containsKey(url)) return cache[url]!;
    final res = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    cache[url] = data;
    return data;
  }
  Future<List<Entry>> list() async {
    final data = await get('$root/pokemon?limit=2000');
    return (data['results'] as List).map((e) => Entry(e['name'] as String, urlId(e['url'] as String))).toList();
  }
  Future<List<Entry>> byType(String type) async {
    final data = await get('$root/type/$type');
    final result = (data['pokemon'] as List).map((e) => Entry(e['pokemon']['name'] as String, urlId(e['pokemon']['url'] as String))).toList();
    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }
  Future<Detail> detail(String name) async {
    final p = await get('$root/pokemon/$name');
    final s = await get(p['species']['url'] as String);
    Map<String, dynamic>? evolution;
    try {
      if (s['evolution_chain']?['url'] != null) evolution = await get(s['evolution_chain']['url'] as String);
    } catch (_) { /* Overview still usable without evolution. */ }
    return Detail(p, s, evolution);
  }
  void dispose() => client.close();
}

class Entry {
  final String name;
  final int id;
  const Entry(this.name, this.id);
}

class Detail {
  final Map<String, dynamic> p, s;
  final Map<String, dynamic>? chain;
  Detail(this.p, this.s, this.chain);
  int get id => p['id'] as int;
  String get name => p['name'] as String;
  List<String> get types => (p['types'] as List).map((e) => e['type']['name'] as String).toList();
  String get description {
    for (final e in (s['flavor_text_entries'] as List).reversed) {
      if (e['language']['name'] == 'en') return (e['flavor_text'] as String).replaceAll(RegExp(r'[\n\f\r]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return 'No description available.';
  }
  String get genus {
    for (final e in s['genera'] as List) {
      if (e['language']['name'] == 'en') return e['genus'] as String;
    }
    return 'Pokémon';
  }
  List<Entry> get evolutions {
    final found = <Entry>[];
    void walk(dynamic node) {
      if (node is! Map) return;
      final spec = node['species'];
      if (spec is Map) found.add(Entry(spec['name'] as String, urlId(spec['url'] as String)));
      for (final next in (node['evolves_to'] as List? ?? [])) { walk(next); }
    }
    if (chain != null) walk(chain!['chain']);
    return found;
  }
}

void main() => runApp(const NoirApp());

class NoirApp extends StatelessWidget {
  const NoirApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Pokédex Noir',
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
      fontFamily: 'Roboto', appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: white)),
    home: const ExplorePage(),
  );
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final api = Api();
  final controller = TextEditingController();
  late Future<List<Entry>> all;
  String search = '';
  String type = 'all';
  final types = const ['all', 'fire', 'water', 'grass', 'electric', 'psychic', 'dragon', 'ghost', 'fairy', 'dark', 'ice', 'fighting', 'normal', 'bug', 'poison', 'ground', 'rock', 'flying', 'steel'];
  @override
  void initState() { super.initState(); all = api.list(); }
  @override
  void dispose() { controller.dispose(); api.dispose(); super.dispose(); }
  void pickType(String selected) { setState(() { type = selected; all = selected == 'all' ? api.list() : api.byType(selected); }); }
  void open(String name) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailPage(api: api, name: name)));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: RefreshIndicator(
      color: accent, backgroundColor: panel,
      onRefresh: () async { setState(() => all = type == 'all' ? api.list() : api.byType(type)); await all; },
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 10), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.catching_pokemon, color: bg, size: 29)),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('POKÉDEX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.4)), Text('NOIR EDITION', style: TextStyle(fontSize: 9, letterSpacing: 3, color: dim, fontWeight: FontWeight.w700))]),
              const Spacer(),
              const Icon(Icons.tune_rounded, color: dim),
            ]),
            const SizedBox(height: 40),
            const Text('THE WORLD OF', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 3)),
            const SizedBox(height: 9),
            const Text('Pokémon,\nreimagined.', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 43, height: 1.09, letterSpacing: -1.7)),
            const SizedBox(height: 13),
            const Text('Meet every Pokémon. Explore every detail.', style: TextStyle(color: dim, fontSize: 13)),
            const SizedBox(height: 26),
            TextField(controller: controller, onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
              style: const TextStyle(fontWeight: FontWeight.w600, color: white),
              decoration: InputDecoration(hintText: 'Search Pokémon or Pokédex number', hintStyle: const TextStyle(color: dim, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: accent),
                suffixIcon: search.isEmpty ? null : IconButton(onPressed: () { controller.clear(); setState(() => search = ''); }, icon: const Icon(Icons.close, color: dim)),
                filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 19)),
            ),
            const SizedBox(height: 26),
            const Row(children: [Text('DISCOVER BY TYPE', style: TextStyle(fontSize: 11, color: dim, letterSpacing: 1.5, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 12),
          ],
        ))),
        SliverToBoxAdapter(child: SizedBox(height: 40, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 22), scrollDirection: Axis.horizontal,
          itemCount: types.length, separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (_, i) { final t = types[i]; final chosen = type == t; return InkWell(onTap: () => pickType(t), borderRadius: BorderRadius.circular(13), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17), alignment: Alignment.center,
            decoration: BoxDecoration(color: chosen ? accent : panel, borderRadius: BorderRadius.circular(13), border: Border.all(color: chosen ? accent : const Color(0xFF27334A))),
            child: Text(cap(t), style: TextStyle(color: chosen ? bg : dim, fontSize: 12, fontWeight: FontWeight.w800)),
          )); },
        ))),
        FutureBuilder<List<Entry>>(future: all, builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: accent)));
          if (snap.hasError) return SliverFillRemaining(child: RetryPanel(onRetry: () => pickType(type)));
          final entries = snap.data!.where((e) => e.name.contains(search) || e.id.toString() == search || tag(e.id).toLowerCase() == search).toList();
          return SliverMainAxisGroup(slivers: [
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 28, 22, 18), child: Row(children: [
              const Text('Collection', style: TextStyle(color: white, fontSize: 24, fontWeight: FontWeight.w900)),
              const Spacer(), Text('${entries.length} found', style: const TextStyle(color: dim, fontSize: 12)),
            ]))),
            if (entries.isEmpty) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(45), child: Center(child: Text('No Pokémon found', style: TextStyle(color: dim)))))
            else SliverPadding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 36), sliver: SliverLayoutBuilder(builder: (_, c) {
              final columns = c.crossAxisExtent > 760 ? 4 : c.crossAxisExtent > 480 ? 3 : 2;
              return SliverGrid.builder(itemCount: entries.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .77),
                itemBuilder: (_, i) => PokemonTile(entry: entries[i], onTap: () => open(entries[i].name)));
            })),
          ]);
        }),
      ]),
    )),
  );
}

class PokemonTile extends StatelessWidget {
  final Entry entry;
  final VoidCallback onTap;
  const PokemonTile({super.key, required this.entry, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: panel, borderRadius: BorderRadius.circular(22), child: InkWell(
    borderRadius: BorderRadius.circular(22), onTap: onTap,
    child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF27344A))),
      child: Stack(children: [
        Positioned(top: 12, right: 11, child: Text(tag(entry.id), style: const TextStyle(color: dim, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6))),
        Positioned(top: 20, right: -19, child: Icon(Icons.catching_pokemon, color: white.withValues(alpha: .035), size: 150)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 22, 14, 0), child: Hero(tag: 'poke-${entry.id}', child: Image.network(art(entry.id), fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.catching_pokemon, color: dim, size: 55)))))),
          Padding(padding: const EdgeInsets.fromLTRB(15, 2, 12, 17), child: Row(children: [
            Expanded(child: Text(cap(entry.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
            const SizedBox(width: 5), const Icon(Icons.arrow_outward_rounded, color: accent, size: 18),
          ])),
        ]),
      ]),
    ),
  ));
}

class DetailPage extends StatefulWidget {
  final Api api;
  final String name;
  const DetailPage({super.key, required this.api, required this.name});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Future<Detail> future;
  int tab = 0;
  bool shiny = false;
  @override void initState() { super.initState(); future = widget.api.detail(widget.name); }
  void navigate(String name) { if (name == widget.name) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DetailPage(api: widget.api, name: name))); }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: FutureBuilder<Detail>(future: future, builder: (context, snap) {
    if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: accent));
    if (snap.hasError) return RetryPanel(onRetry: () => setState(() => future = widget.api.detail(widget.name)));
    final d = snap.data!;
    final tint = typeColor(d.types.first);
    return CustomScrollView(slivers: [SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Row(children: [
        _roundButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
        const Spacer(), Text(tag(d.id), style: const TextStyle(color: dim, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 13)),
        const Spacer(), _roundButton(shiny ? Icons.auto_awesome : Icons.auto_awesome_outlined, () => setState(() => shiny = !shiny)),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(25, 20, 25, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.genus.toUpperCase(), style: TextStyle(color: tint, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.3)),
        const SizedBox(height: 8), Text(cap(d.name), style: const TextStyle(fontSize: 39, fontWeight: FontWeight.w900, letterSpacing: -1.3)),
        const SizedBox(height: 14), Wrap(spacing: 8, children: d.types.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7), decoration: BoxDecoration(color: typeColor(t).withValues(alpha: .14), borderRadius: BorderRadius.circular(10)), child: Text(cap(t), style: TextStyle(fontSize: 12, color: typeColor(t), fontWeight: FontWeight.w800)))).toList()),
      ])),
      SizedBox(height: 315, child: Stack(alignment: Alignment.center, children: [
        Container(width: 255, height: 255, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [tint.withValues(alpha: .20), bg], stops: const [.15, 1]))),
        Icon(Icons.catching_pokemon, size: 284, color: white.withValues(alpha: .045)),
        Hero(tag: 'poke-${d.id}', child: Image.network(art(d.id, shiny: shiny), height: 272, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon, size: 130, color: dim))),
        if (shiny) const Positioned(right: 22, bottom: 14, child: Text('✨ SHINY FORM', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1))),
      ])),
      Container(decoration: const BoxDecoration(color: panel, borderRadius: BorderRadius.vertical(top: Radius.circular(33))),
        child: Padding(padding: const EdgeInsets.fromLTRB(22, 25, 22, 38), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(4, (i) {
            const tabs = ['Overview', 'Stats', 'Evolution', 'Moves'];
            return Padding(padding: const EdgeInsets.only(right: 22), child: InkWell(onTap: () => setState(() => tab = i), child: Column(children: [
              Text(tabs[i], style: TextStyle(color: i == tab ? accent : dim, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 13), Container(width: 30, height: 3, decoration: BoxDecoration(color: i == tab ? accent : Colors.transparent, borderRadius: BorderRadius.circular(2))),
            ])));
          }))),
          const SizedBox(height: 26),
          if (tab == 0) overview(d) else if (tab == 1) stats(d) else if (tab == 2) evolution(d) else moves(d),
        ]))),
    ]))]);
  })));

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(color: panel, borderRadius: BorderRadius.circular(13), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(13), child: SizedBox(width: 43, height: 43, child: Icon(icon, size: 20, color: white))));
  Widget heading(String label) => Padding(padding: const EdgeInsets.only(bottom: 13), child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)));
  Widget info(String label, String value) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: panel2, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: dim)), const SizedBox(height: 7), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))]));
  Widget overview(Detail d) {
    final abilities = (d.p['abilities'] as List).map((e) => cap(e['ability']['name'] as String)).join(', ');
    final eggGroups = (d.s['egg_groups'] as List).map((e) => cap(e['name'] as String)).join(', ');
    final habitat = d.s['habitat']?['name'] as String?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('About this Pokémon'),
      Text(d.description, style: const TextStyle(color: dim, height: 1.65, fontSize: 14)),
      const SizedBox(height: 24),
      Row(children: [Expanded(child: info('HEIGHT', '${((d.p['height'] as num) / 10).toStringAsFixed(1)} m')), const SizedBox(width: 11), Expanded(child: info('WEIGHT', '${((d.p['weight'] as num) / 10).toStringAsFixed(1)} kg'))]),
      const SizedBox(height: 11),
      Row(children: [Expanded(child: info('BASE EXPERIENCE', '${d.p['base_experience'] ?? '—'}')), const SizedBox(width: 11), Expanded(child: info('CAPTURE RATE', '${d.s['capture_rate'] ?? '—'}'))]),
      const SizedBox(height: 25), heading('Biology & habitat'),
      info('ABILITIES', abilities), const SizedBox(height: 10), info('HABITAT', habitat == null ? 'Unknown' : cap(habitat)),
      const SizedBox(height: 10), info('EGG GROUPS', eggGroups.isEmpty ? 'Unknown' : eggGroups),
      const SizedBox(height: 10), info('GENERATION', cap((d.s['generation']?['name'] as String?) ?? 'Unknown')),
      const SizedBox(height: 10), info('HATCH COUNTER', '${d.s['hatch_counter'] ?? '—'}'),
    ]);
  }
  Widget stats(Detail d) {
    final entries = (d.p['stats'] as List);
    final sum = entries.fold<int>(0, (total, e) => total + (e['base_stat'] as int));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('Base stats'), Text('Total base stats: $sum', style: const TextStyle(color: dim, fontSize: 13)), const SizedBox(height: 19),
      ...entries.map((e) {
        final name = e['stat']['name'] as String;
        final value = e['base_stat'] as int;
        final color = value >= 100 ? accent : value >= 65 ? const Color(0xFFFFD76D) : const Color(0xFFFF8A65);
        final label = <String, String>{'hp':'HP', 'attack':'Attack', 'defense':'Defense', 'special-attack':'Sp. Atk', 'special-defense':'Sp. Def', 'speed':'Speed'}[name] ?? cap(name);
        return Padding(padding: const EdgeInsets.only(bottom: 21), child: Row(children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w700))),
          SizedBox(width: 35, child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: math.min(value / 200, 1.0), minHeight: 9, backgroundColor: panel2, valueColor: AlwaysStoppedAnimation<Color>(color)))),
        ]));
      }),
    ]);
  }
  Widget evolution(Detail d) {
    final es = d.evolutions;
    if (es.isEmpty) return const Text('Evolution data is not available.', style: TextStyle(color: dim));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('Evolution chain'), const Text('Tap an evolution to explore its details.', style: TextStyle(color: dim, fontSize: 12)), const SizedBox(height: 16),
      ...es.asMap().entries.map((indexed) { final e = indexed.value; return Column(children: [
        InkWell(onTap: () => navigate(e.name), borderRadius: BorderRadius.circular(17), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: panel2, borderRadius: BorderRadius.circular(17)), child: Row(children: [
          Image.network(art(e.id), width: 82, height: 82, errorBuilder: (_, __, ___) => const SizedBox(width: 82, height: 82)),
          const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tag(e.id), style: const TextStyle(color: dim, fontSize: 11)), const SizedBox(height: 5), Text(cap(e.name), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))])),
          const Icon(Icons.arrow_outward_rounded, color: accent),
        ]))),
        if (indexed.key < es.length - 1) const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.keyboard_arrow_down_rounded, color: accent, size: 25)),
      ]); }),
    ]);
  }
  Widget moves(Detail d) {
    final items = (d.p['moves'] as List).map((e) => cap(e['move']['name'] as String)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('Moves & techniques'), Text('${items.length} moves available across game versions', style: const TextStyle(color: dim, fontSize: 12)), const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 9, children: items.map((move) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: panel2, borderRadius: BorderRadius.circular(10)), child: Text(move, style: const TextStyle(color: white, fontSize: 12, fontWeight: FontWeight.w600)))).toList()),
    ]);
  }
}

class RetryPanel extends StatelessWidget {
  final VoidCallback onRetry;
  const RetryPanel({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, color: dim, size: 40), const SizedBox(height: 12),
    const Text('Unable to reach PokéAPI', style: TextStyle(fontWeight: FontWeight.w800)),
    const SizedBox(height: 7), const Text('Check your connection and try again.', style: TextStyle(color: dim)),
    const SizedBox(height: 16), FilledButton(onPressed: onRetry, child: const Text('Retry')),
  ])));
}
