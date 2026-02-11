# ilk_deneme

A new Flutter project.

## Supabase Migration (Önemli)

Satış yaparken **"Could not find the 'commission' column of 'transactions'"** hatası alıyorsanız:

1. Supabase Dashboard'a gidin
2. **SQL Editor** sekmesini açın
3. `supabase_migration_v6_komisyon.sql` dosyasının içeriğini yapıştırıp çalıştırın

Bu migration, `transactions` tablosuna `commission` kolonunu ekler.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
