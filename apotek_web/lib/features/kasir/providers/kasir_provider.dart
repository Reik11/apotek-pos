import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/drug_model.dart';

// Model item di keranjang
class CartItem {
  final DrugModel drug;
  int quantity;

  CartItem({required this.drug, required this.quantity});

  double get subtotal => drug.sellPrice * quantity;
}

// State kasir
class KasirState {
  final List<DrugModel> searchResults;
  final List<CartItem> cartItems;
  final bool isSearching;
  final bool isProcessing;
  final String? error;
  final Map<String, dynamic>? lastTransaction;

  KasirState({
    this.searchResults = const [],
    this.cartItems = const [],
    this.isSearching = false,
    this.isProcessing = false,
    this.error,
    this.lastTransaction,
  });

  double get totalAmount =>
      cartItems.fold(0, (sum, item) => sum + item.subtotal);

  KasirState copyWith({
    List<DrugModel>? searchResults,
    List<CartItem>? cartItems,
    bool? isSearching,
    bool? isProcessing,
    String? error,
    Map<String, dynamic>? lastTransaction,
  }) {
    return KasirState(
      searchResults: searchResults ?? this.searchResults,
      cartItems: cartItems ?? this.cartItems,
      isSearching: isSearching ?? this.isSearching,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      lastTransaction: lastTransaction ?? this.lastTransaction,
    );
  }
}

// Kasir Notifier
class KasirNotifier extends StateNotifier<KasirState> {
  final Dio _dio = ApiClient.createDio();

  KasirNotifier() : super(KasirState());

  // Cari obat
  Future<void> searchDrugs(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }
    state = state.copyWith(isSearching: true);
    try {
      final response = await _dio.get('/drugs?search=$query');
      final drugs =
          (response.data as List).map((d) => DrugModel.fromJson(d)).toList();
      state = state.copyWith(searchResults: drugs, isSearching: false);
    } catch (e) {
      state = state.copyWith(isSearching: false);
    }
  }

  // Tambah ke keranjang
  void addToCart(DrugModel drug) {
    final existing =
        state.cartItems.indexWhere((item) => item.drug.id == drug.id);

    if (existing >= 0) {
      // Sudah ada, tambah quantity
      final updated = List<CartItem>.from(state.cartItems);
      updated[existing].quantity++;
      state = state.copyWith(cartItems: updated);
    } else {
      // Belum ada, tambah baru
      state = state.copyWith(
        cartItems: [...state.cartItems, CartItem(drug: drug, quantity: 1)],
      );
    }
  }

  // Update quantity
  void updateQuantity(String drugId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(drugId);
      return;
    }
    final updated = state.cartItems.map((item) {
      if (item.drug.id == drugId) {
        return CartItem(drug: item.drug, quantity: quantity);
      }
      return item;
    }).toList();
    state = state.copyWith(cartItems: updated);
  }

  // Hapus dari keranjang
  void removeFromCart(String drugId) {
    state = state.copyWith(
      cartItems:
          state.cartItems.where((item) => item.drug.id != drugId).toList(),
    );
  }

  // Kosongkan keranjang
  void clearCart() {
    state = state.copyWith(
      cartItems: [],
      lastTransaction: null,
      searchResults: [],
    );
  }

  // Proses transaksi
  Future<bool> processTransaction({
    required String paymentMethod,
    required double amountPaid,
  }) async {
    if (state.cartItems.isEmpty) return false;

    state = state.copyWith(isProcessing: true, error: null);
    try {
      final items = state.cartItems
          .map((item) => {
                'drugId': item.drug.id,
                'quantity': item.quantity,
              })
          .toList();

      final response = await _dio.post('/transactions', data: {
        'items': items,
        'paymentMethod': paymentMethod,
        'amountPaid': amountPaid,
      });

      state = state.copyWith(
        isProcessing: false,
        lastTransaction: response.data,
        cartItems: [],
        searchResults: [],
      );
      return true;
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Transaksi gagal';
      state = state.copyWith(isProcessing: false, error: message);
      return false;
    }
  }
}

final kasirProvider = StateNotifierProvider<KasirNotifier, KasirState>((ref) {
  return KasirNotifier();
});
