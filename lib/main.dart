import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MovieSearchApp());

const _seedColor = Color(0xFF3F51B5);

class MovieSearchApp extends StatelessWidget {
  const MovieSearchApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);
    return ThemeData(
      colorScheme: colors,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buscador de películas',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const MovieSearchPage(),
    );
  }
}

class Movie {
  const Movie({required this.title, this.posterUrl});

  final String title;
  final String? posterUrl;

  factory Movie.fromJson(Map<String, dynamic> json) {
    final poster = json['Poster'] as String?;
    return Movie(
      title: json['Title'] as String,
      posterUrl: poster == null || poster == 'N/A' ? null : poster,
    );
  }
}

class MoviePage {
  const MoviePage({required this.movies, required this.totalResults});

  final List<Movie> movies;
  final int totalResults;
}

class MovieSearchException implements Exception {
  const MovieSearchException(this.message);

  final String message;
}

class OmdbService {
  static const _apiKey = String.fromEnvironment('OMDB_API_KEY');

  Future<MoviePage> search(String query, int page) async {
    if (_apiKey.isEmpty) {
      throw const MovieSearchException(
        'Falta la API key de OMDb. Corre la app con --dart-define=OMDB_API_KEY=tu_key.',
      );
    }

    final uri = Uri.https('www.omdbapi.com', '/', {
      'apikey': _apiKey,
      's': query,
      'page': '$page',
    });
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw MovieSearchException('La API respondió con el código ${response.statusCode}.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['Response'] == 'False') {
      final error = data['Error'] as String? ?? '';
      if (error == 'Movie not found!') {
        return const MoviePage(movies: [], totalResults: 0);
      }
      throw MovieSearchException(_translateError(error));
    }

    final results = data['Search'] as List<dynamic>;
    return MoviePage(
      movies: results.map((item) => Movie.fromJson(item as Map<String, dynamic>)).toList(),
      totalResults: int.tryParse(data['totalResults'] as String? ?? '') ?? 0,
    );
  }

  String _translateError(String error) => switch (error) {
        'Invalid API key!' => 'La API key de OMDb no es válida.',
        'Too many results.' => 'Hay demasiados resultados. Escribe un título más específico.',
        'Request limit reached!' => 'Se alcanzó el límite diario de consultas de OMDb.',
        _ => 'OMDb respondió: $error',
      };
}

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({super.key});

  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  static const _minLength = 3;
  static const _loadMoreThreshold = 300.0;

  final _formKey = GlobalKey<FormState>();
  final _confirmKey = GlobalKey<FormFieldState<String>>();
  final _queryController = TextEditingController();
  final _confirmController = TextEditingController();
  final _scrollController = ScrollController();
  final _service = OmdbService();

  final _movies = <Movie>[];
  String? _query;
  int _page = 0;
  int _totalResults = 0;
  bool _isLoading = false;
  String? _error;
  int _searchId = 0;

  bool get _hasMore => _query != null && _movies.length < _totalResults;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _confirmController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _validateQuery(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) return 'Escribe el título de una película.';
    if (text.trim().length < _minLength) {
      final missing = _minLength - text.trim().length;
      final detail = missing == 1 ? 'falta 1 carácter' : 'faltan $missing caracteres';
      return 'Te $detail: el mínimo es $_minLength.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Repite el título para confirmarlo.';
    if (text != _queryController.text) return 'No coincide con el título de arriba.';
    return null;
  }

  void _onQueryChanged(String _) {
    if (_confirmController.text.isNotEmpty) _confirmKey.currentState?.validate();
  }

  void _startSearch() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _searchId++;
      _query = _queryController.text.trim();
      _movies.clear();
      _page = 0;
      _totalResults = 0;
      _isLoading = false;
      _error = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    final query = _query;
    if (query == null || _isLoading) return;

    final searchId = _searchId;
    final nextPage = _page + 1;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.search(query, nextPage);
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _movies.addAll(result.movies);
        _page = nextPage;
        _totalResults = result.movies.isEmpty ? _movies.length : result.totalResults;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    } catch (error) {
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _isLoading = false;
        _error = error is MovieSearchException
            ? error.message
            : 'No se pudo conectar con OMDb. Revisa tu conexión a internet.';
      });
    }
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || !_hasMore || _isLoading || _error != null) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscador de películas')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ValidatedField(
                          controller: _queryController,
                          label: 'Película',
                          helper: 'Mínimo $_minLength caracteres',
                          validator: _validateQuery,
                          onChanged: _onQueryChanged,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        ValidatedField(
                          fieldKey: _confirmKey,
                          controller: _confirmController,
                          label: 'Confirmar película',
                          helper: 'Debe ser igual al título de arriba',
                          validator: _validateConfirmation,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _startSearch(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _startSearch,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _buildResults()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_query == null) {
      return const StatusMessage(message: 'Escribe un título y confírmalo para buscar.');
    }

    if (_movies.isEmpty) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return StatusMessage(message: _error!, actionLabel: 'Reintentar', onAction: _loadNextPage);
      }
      return StatusMessage(message: 'No se encontraron resultados para "$_query".');
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _movies.length + 1,
      itemBuilder: (context, index) {
        if (index < _movies.length) return MovieTile(movie: _movies[index]);
        return _buildFooter();
      },
    );
  }

  Widget _buildFooter() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return StatusMessage(message: _error!, actionLabel: 'Reintentar', onAction: _loadNextPage);
    }
    if (!_hasMore) {
      return StatusMessage(message: 'No hay más resultados (${_movies.length} en total).');
    }
    return const SizedBox(height: 72);
  }
}

class MovieTile extends StatelessWidget {
  const MovieTile({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          MoviePoster(url: movie.posterUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class MoviePoster extends StatelessWidget {
  const MoviePoster({super.key, this.url});

  static const _width = 48.0;
  static const _height = 72.0;

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: _width,
      height: _height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: _width,
              height: _height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ValidatedField extends StatelessWidget {
  const ValidatedField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.label,
    required this.helper,
    required this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final GlobalKey<FormFieldState<String>>? fieldKey;
  final TextEditingController controller;
  final String label;
  final String helper;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: fieldKey,
      initialValue: controller.text,
      validator: (_) => validator(controller.text),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) {
        final error = state.errorText;
        return TextField(
          controller: controller,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: (value) {
            state.didChange(value);
            onChanged?.call(value);
          },
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            error: error == null ? null : ErrorMessage(error),
          ),
        );
      },
    );
  }
}

class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Semantics(
      liveRegion: true,
      label: 'Error: $message',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Icon(Icons.cancel_rounded, size: 16, color: color),
            ),
          ),
          TextSpan(text: message),
        ]),
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
