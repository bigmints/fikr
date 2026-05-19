import 'package:flutter_contacts/flutter_contacts.dart';
import '../tool_interface.dart';

class ContactsAddTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'contacts.add';

  @override
  String get description => 'Add a new contact to the device address book.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'firstName': {'type': 'string'},
      'lastName': {'type': 'string'},
      'phone': {'type': 'string'},
      'email': {'type': 'string'},
      'company': {'type': 'string'},
    },
    'required': ['firstName'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(Map<String, dynamic> params, ToolContext context) =>
      guard(context, () async {
        final status = await FlutterContacts.permissions.request(PermissionType.write);
        if (status != PermissionStatus.granted) {
          return ToolResult.fail('Contact permission denied.');
        }

        final contact = Contact(
          name: Name(
            first: params['firstName'] as String,
            last: params['lastName'] as String? ?? '',
          ),
          phones: params['phone'] != null ? [Phone(number: params['phone'] as String)] : [],
          emails: params['email'] != null ? [Email(address: params['email'] as String)] : [],
          organizations: params['company'] != null ? [Organization(name: params['company'] as String)] : [],
        );

        final id = await FlutterContacts.create(contact);
        return ToolResult.ok({'success': true, 'contactId': id});
      });
}

List<FikrTool> allContactsTools() => [
      ContactsAddTool(),
    ];
