import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Access Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ContactPage(),
    );
  }
}

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});
  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _loading = false;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionAndFetch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndFetch() async {
    setState(() => _loading = true);
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      await _fetchContacts();
    } else if (status.isDenied || status.isLimited) {
      final result = await Permission.contacts.request();
      if (result.isGranted) {
        await _fetchContacts();
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _contacts = [];
            _filteredContacts = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin akses kontak ditolak')),
          );
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _loading = false;
          _contacts = [];
          _filteredContacts = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin akses kontak ditolak permanen. Aktifkan lewat pengaturan.'),
          ),
        );
      }
      openAppSettings();
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
          _contacts = [];
          _filteredContacts = [];
        });
      }
    }
  }

  Future<void> _fetchContacts() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      final contactsWithPhone = contacts.where((c) => c.phones.isNotEmpty).toList();
      contactsWithPhone.sort((a, b) => a.displayName.compareTo(b.displayName));
      if (!mounted) return;
      setState(() {
        _contacts = contactsWithPhone;
        _filteredContacts = contactsWithPhone;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _contacts = [];
          _filteredContacts = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil kontak: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;

      // Normalisasi query untuk pencocokan nomor
      final normalizedQuery = query.replaceAll(' ', '').replaceFirst(RegExp(r'^0'), '+62');

      _filteredContacts = _contacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        final phones = contact.phones.map((p) {
          final number = p.number.replaceAll(RegExp(r'\s+'), '');
          final normalizedNumber = number.replaceFirst(RegExp(r'^\+62'), '0');
          return {
            'original': number,
            'normalized': normalizedNumber,
          };
        }).toList();

        final phoneMatches = phones.any((phone) =>
        phone['original']!.contains(query) || phone['normalized']!.contains(query));

        return name.contains(query.toLowerCase()) || phoneMatches;
      }).toList();
    });
  }


  Future<void> _showContactDetail(Contact contact) async {
    await showDialog(
        context: context,
        builder: (context) {
      return AlertDialog(
          title: Text(contact.displayName),
    content: SingleChildScrollView(
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    if (contact.photoOrThumbnail != null)
    CircleAvatar(
    radius: 40,
    backgroundImage: MemoryImage(contact.photoOrThumbnail!),
    ),
    const SizedBox(height: 10),
    ...contact.phones.map((phone) => Text(phone.number)),
    ],
    ),
    ),
    actions: [
      TextButton(
        onPressed: () async {
          Navigator.pop(context);
          final updated = await FlutterContacts.openExternalEdit(contact.id);
          if (updated == true) {
            await _fetchContacts();
          }
        },
        child: const Text('Edit'),
      ),
      TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Text('Tutup'),
      ),
    ],
      );
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Kontak'),
        backgroundColor: primaryColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama atau nomor...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchContacts,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  return ListTile(
                    onTap: () => _showContactDetail(contact),
                    leading: contact.photoOrThumbnail != null
                        ? CircleAvatar(
                      backgroundImage:
                      MemoryImage(contact.photoOrThumbnail!),
                    )
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(contact.displayName),
                    subtitle: contact.phones.isNotEmpty
                        ? Text(contact.phones.first.number)
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}