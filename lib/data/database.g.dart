// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountGroupsTable extends AccountGroups
    with TableInfo<$AccountGroupsTable, AccountGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _primaryGroupMeta = const VerificationMeta(
    'primaryGroup',
  );
  @override
  late final GeneratedColumn<String> primaryGroup = GeneratedColumn<String>(
    'primary_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, primaryGroup];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('primary_group')) {
      context.handle(
        _primaryGroupMeta,
        primaryGroup.isAcceptableOrUnknown(
          data['primary_group']!,
          _primaryGroupMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_primaryGroupMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      primaryGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_group'],
      )!,
    );
  }

  @override
  $AccountGroupsTable createAlias(String alias) {
    return $AccountGroupsTable(attachedDatabase, alias);
  }
}

class AccountGroup extends DataClass implements Insertable<AccountGroup> {
  final String id;
  final String name;
  final String primaryGroup;
  const AccountGroup({
    required this.id,
    required this.name,
    required this.primaryGroup,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['primary_group'] = Variable<String>(primaryGroup);
    return map;
  }

  AccountGroupsCompanion toCompanion(bool nullToAbsent) {
    return AccountGroupsCompanion(
      id: Value(id),
      name: Value(name),
      primaryGroup: Value(primaryGroup),
    );
  }

  factory AccountGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      primaryGroup: serializer.fromJson<String>(json['primaryGroup']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'primaryGroup': serializer.toJson<String>(primaryGroup),
    };
  }

  AccountGroup copyWith({String? id, String? name, String? primaryGroup}) =>
      AccountGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        primaryGroup: primaryGroup ?? this.primaryGroup,
      );
  AccountGroup copyWithCompanion(AccountGroupsCompanion data) {
    return AccountGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      primaryGroup: data.primaryGroup.present
          ? data.primaryGroup.value
          : this.primaryGroup,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('primaryGroup: $primaryGroup')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, primaryGroup);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.primaryGroup == this.primaryGroup);
}

class AccountGroupsCompanion extends UpdateCompanion<AccountGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> primaryGroup;
  final Value<int> rowid;
  const AccountGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.primaryGroup = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountGroupsCompanion.insert({
    required String id,
    required String name,
    required String primaryGroup,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       primaryGroup = Value(primaryGroup);
  static Insertable<AccountGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? primaryGroup,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (primaryGroup != null) 'primary_group': primaryGroup,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? primaryGroup,
    Value<int>? rowid,
  }) {
    return AccountGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryGroup: primaryGroup ?? this.primaryGroup,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (primaryGroup.present) {
      map['primary_group'] = Variable<String>(primaryGroup.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('primaryGroup: $primaryGroup, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgersTable extends Ledgers with TableInfo<$LedgersTable, Ledger> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingBalanceMeta = const VerificationMeta(
    'openingBalance',
  );
  @override
  late final GeneratedColumn<double> openingBalance = GeneratedColumn<double>(
    'opening_balance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxNumberMeta = const VerificationMeta(
    'taxNumber',
  );
  @override
  late final GeneratedColumn<String> taxNumber = GeneratedColumn<String>(
    'tax_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    groupId,
    openingBalance,
    phone,
    address,
    email,
    taxNumber,
    updatedAt,
    isSynced,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledgers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ledger> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('opening_balance')) {
      context.handle(
        _openingBalanceMeta,
        openingBalance.isAcceptableOrUnknown(
          data['opening_balance']!,
          _openingBalanceMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('tax_number')) {
      context.handle(
        _taxNumberMeta,
        taxNumber.isAcceptableOrUnknown(data['tax_number']!, _taxNumberMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ledger map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ledger(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      openingBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}opening_balance'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      taxNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_number'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $LedgersTable createAlias(String alias) {
    return $LedgersTable(attachedDatabase, alias);
  }
}

class Ledger extends DataClass implements Insertable<Ledger> {
  final String id;
  final String name;
  final String groupId;
  final double openingBalance;
  final String? phone;
  final String? address;
  final String? email;
  final String? taxNumber;
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;
  const Ledger({
    required this.id,
    required this.name,
    required this.groupId,
    required this.openingBalance,
    this.phone,
    this.address,
    this.email,
    this.taxNumber,
    required this.updatedAt,
    required this.isSynced,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['group_id'] = Variable<String>(groupId);
    map['opening_balance'] = Variable<double>(openingBalance);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || taxNumber != null) {
      map['tax_number'] = Variable<String>(taxNumber);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  LedgersCompanion toCompanion(bool nullToAbsent) {
    return LedgersCompanion(
      id: Value(id),
      name: Value(name),
      groupId: Value(groupId),
      openingBalance: Value(openingBalance),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      taxNumber: taxNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(taxNumber),
      updatedAt: Value(updatedAt),
      isSynced: Value(isSynced),
      isDeleted: Value(isDeleted),
    );
  }

  factory Ledger.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ledger(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      groupId: serializer.fromJson<String>(json['groupId']),
      openingBalance: serializer.fromJson<double>(json['openingBalance']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      email: serializer.fromJson<String?>(json['email']),
      taxNumber: serializer.fromJson<String?>(json['taxNumber']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'groupId': serializer.toJson<String>(groupId),
      'openingBalance': serializer.toJson<double>(openingBalance),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'email': serializer.toJson<String?>(email),
      'taxNumber': serializer.toJson<String?>(taxNumber),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Ledger copyWith({
    String? id,
    String? name,
    String? groupId,
    double? openingBalance,
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> taxNumber = const Value.absent(),
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
  }) => Ledger(
    id: id ?? this.id,
    name: name ?? this.name,
    groupId: groupId ?? this.groupId,
    openingBalance: openingBalance ?? this.openingBalance,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    email: email.present ? email.value : this.email,
    taxNumber: taxNumber.present ? taxNumber.value : this.taxNumber,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Ledger copyWithCompanion(LedgersCompanion data) {
    return Ledger(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      openingBalance: data.openingBalance.present
          ? data.openingBalance.value
          : this.openingBalance,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      email: data.email.present ? data.email.value : this.email,
      taxNumber: data.taxNumber.present ? data.taxNumber.value : this.taxNumber,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ledger(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupId: $groupId, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    groupId,
    openingBalance,
    phone,
    address,
    email,
    taxNumber,
    updatedAt,
    isSynced,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ledger &&
          other.id == this.id &&
          other.name == this.name &&
          other.groupId == this.groupId &&
          other.openingBalance == this.openingBalance &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.email == this.email &&
          other.taxNumber == this.taxNumber &&
          other.updatedAt == this.updatedAt &&
          other.isSynced == this.isSynced &&
          other.isDeleted == this.isDeleted);
}

class LedgersCompanion extends UpdateCompanion<Ledger> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> groupId;
  final Value<double> openingBalance;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<String?> email;
  final Value<String?> taxNumber;
  final Value<DateTime> updatedAt;
  final Value<bool> isSynced;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const LedgersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.groupId = const Value.absent(),
    this.openingBalance = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgersCompanion.insert({
    required String id,
    required String name,
    required String groupId,
    this.openingBalance = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       groupId = Value(groupId);
  static Insertable<Ledger> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? groupId,
    Expression<double>? openingBalance,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? email,
    Expression<String>? taxNumber,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isSynced,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (groupId != null) 'group_id': groupId,
      if (openingBalance != null) 'opening_balance': openingBalance,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (email != null) 'email': email,
      if (taxNumber != null) 'tax_number': taxNumber,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? groupId,
    Value<double>? openingBalance,
    Value<String?>? phone,
    Value<String?>? address,
    Value<String?>? email,
    Value<String?>? taxNumber,
    Value<DateTime>? updatedAt,
    Value<bool>? isSynced,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return LedgersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
      openingBalance: openingBalance ?? this.openingBalance,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (openingBalance.present) {
      map['opening_balance'] = Variable<double>(openingBalance.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (taxNumber.present) {
      map['tax_number'] = Variable<String>(taxNumber.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupId: $groupId, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockItemsTable extends StockItems
    with TableInfo<$StockItemsTable, StockItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitOfMeasureMeta = const VerificationMeta(
    'unitOfMeasure',
  );
  @override
  late final GeneratedColumn<String> unitOfMeasure = GeneratedColumn<String>(
    'unit_of_measure',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PCS'),
  );
  static const VerificationMeta _openingQuantityMeta = const VerificationMeta(
    'openingQuantity',
  );
  @override
  late final GeneratedColumn<double> openingQuantity = GeneratedColumn<double>(
    'opening_quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _openingRateMeta = const VerificationMeta(
    'openingRate',
  );
  @override
  late final GeneratedColumn<double> openingRate = GeneratedColumn<double>(
    'opening_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _purchaseRateMeta = const VerificationMeta(
    'purchaseRate',
  );
  @override
  late final GeneratedColumn<double> purchaseRate = GeneratedColumn<double>(
    'purchase_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _salesRateMeta = const VerificationMeta(
    'salesRate',
  );
  @override
  late final GeneratedColumn<double> salesRate = GeneratedColumn<double>(
    'sales_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sku,
    unitOfMeasure,
    openingQuantity,
    openingRate,
    purchaseRate,
    salesRate,
    updatedAt,
    isSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('unit_of_measure')) {
      context.handle(
        _unitOfMeasureMeta,
        unitOfMeasure.isAcceptableOrUnknown(
          data['unit_of_measure']!,
          _unitOfMeasureMeta,
        ),
      );
    }
    if (data.containsKey('opening_quantity')) {
      context.handle(
        _openingQuantityMeta,
        openingQuantity.isAcceptableOrUnknown(
          data['opening_quantity']!,
          _openingQuantityMeta,
        ),
      );
    }
    if (data.containsKey('opening_rate')) {
      context.handle(
        _openingRateMeta,
        openingRate.isAcceptableOrUnknown(
          data['opening_rate']!,
          _openingRateMeta,
        ),
      );
    }
    if (data.containsKey('purchase_rate')) {
      context.handle(
        _purchaseRateMeta,
        purchaseRate.isAcceptableOrUnknown(
          data['purchase_rate']!,
          _purchaseRateMeta,
        ),
      );
    }
    if (data.containsKey('sales_rate')) {
      context.handle(
        _salesRateMeta,
        salesRate.isAcceptableOrUnknown(data['sales_rate']!, _salesRateMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      unitOfMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_of_measure'],
      )!,
      openingQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}opening_quantity'],
      )!,
      openingRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}opening_rate'],
      )!,
      purchaseRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purchase_rate'],
      )!,
      salesRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sales_rate'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
    );
  }

  @override
  $StockItemsTable createAlias(String alias) {
    return $StockItemsTable(attachedDatabase, alias);
  }
}

class StockItem extends DataClass implements Insertable<StockItem> {
  final String id;
  final String name;
  final String? sku;
  final String unitOfMeasure;
  final double openingQuantity;
  final double openingRate;
  final double purchaseRate;
  final double salesRate;
  final DateTime updatedAt;
  final bool isSynced;
  const StockItem({
    required this.id,
    required this.name,
    this.sku,
    required this.unitOfMeasure,
    required this.openingQuantity,
    required this.openingRate,
    required this.purchaseRate,
    required this.salesRate,
    required this.updatedAt,
    required this.isSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    map['unit_of_measure'] = Variable<String>(unitOfMeasure);
    map['opening_quantity'] = Variable<double>(openingQuantity);
    map['opening_rate'] = Variable<double>(openingRate);
    map['purchase_rate'] = Variable<double>(purchaseRate);
    map['sales_rate'] = Variable<double>(salesRate);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  StockItemsCompanion toCompanion(bool nullToAbsent) {
    return StockItemsCompanion(
      id: Value(id),
      name: Value(name),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      unitOfMeasure: Value(unitOfMeasure),
      openingQuantity: Value(openingQuantity),
      openingRate: Value(openingRate),
      purchaseRate: Value(purchaseRate),
      salesRate: Value(salesRate),
      updatedAt: Value(updatedAt),
      isSynced: Value(isSynced),
    );
  }

  factory StockItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockItem(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String?>(json['sku']),
      unitOfMeasure: serializer.fromJson<String>(json['unitOfMeasure']),
      openingQuantity: serializer.fromJson<double>(json['openingQuantity']),
      openingRate: serializer.fromJson<double>(json['openingRate']),
      purchaseRate: serializer.fromJson<double>(json['purchaseRate']),
      salesRate: serializer.fromJson<double>(json['salesRate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String?>(sku),
      'unitOfMeasure': serializer.toJson<String>(unitOfMeasure),
      'openingQuantity': serializer.toJson<double>(openingQuantity),
      'openingRate': serializer.toJson<double>(openingRate),
      'purchaseRate': serializer.toJson<double>(purchaseRate),
      'salesRate': serializer.toJson<double>(salesRate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  StockItem copyWith({
    String? id,
    String? name,
    Value<String?> sku = const Value.absent(),
    String? unitOfMeasure,
    double? openingQuantity,
    double? openingRate,
    double? purchaseRate,
    double? salesRate,
    DateTime? updatedAt,
    bool? isSynced,
  }) => StockItem(
    id: id ?? this.id,
    name: name ?? this.name,
    sku: sku.present ? sku.value : this.sku,
    unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
    openingQuantity: openingQuantity ?? this.openingQuantity,
    openingRate: openingRate ?? this.openingRate,
    purchaseRate: purchaseRate ?? this.purchaseRate,
    salesRate: salesRate ?? this.salesRate,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
  );
  StockItem copyWithCompanion(StockItemsCompanion data) {
    return StockItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sku: data.sku.present ? data.sku.value : this.sku,
      unitOfMeasure: data.unitOfMeasure.present
          ? data.unitOfMeasure.value
          : this.unitOfMeasure,
      openingQuantity: data.openingQuantity.present
          ? data.openingQuantity.value
          : this.openingQuantity,
      openingRate: data.openingRate.present
          ? data.openingRate.value
          : this.openingRate,
      purchaseRate: data.purchaseRate.present
          ? data.purchaseRate.value
          : this.purchaseRate,
      salesRate: data.salesRate.present ? data.salesRate.value : this.salesRate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('unitOfMeasure: $unitOfMeasure, ')
          ..write('openingQuantity: $openingQuantity, ')
          ..write('openingRate: $openingRate, ')
          ..write('purchaseRate: $purchaseRate, ')
          ..write('salesRate: $salesRate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sku,
    unitOfMeasure,
    openingQuantity,
    openingRate,
    purchaseRate,
    salesRate,
    updatedAt,
    isSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.unitOfMeasure == this.unitOfMeasure &&
          other.openingQuantity == this.openingQuantity &&
          other.openingRate == this.openingRate &&
          other.purchaseRate == this.purchaseRate &&
          other.salesRate == this.salesRate &&
          other.updatedAt == this.updatedAt &&
          other.isSynced == this.isSynced);
}

class StockItemsCompanion extends UpdateCompanion<StockItem> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> sku;
  final Value<String> unitOfMeasure;
  final Value<double> openingQuantity;
  final Value<double> openingRate;
  final Value<double> purchaseRate;
  final Value<double> salesRate;
  final Value<DateTime> updatedAt;
  final Value<bool> isSynced;
  final Value<int> rowid;
  const StockItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.unitOfMeasure = const Value.absent(),
    this.openingQuantity = const Value.absent(),
    this.openingRate = const Value.absent(),
    this.purchaseRate = const Value.absent(),
    this.salesRate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockItemsCompanion.insert({
    required String id,
    required String name,
    this.sku = const Value.absent(),
    this.unitOfMeasure = const Value.absent(),
    this.openingQuantity = const Value.absent(),
    this.openingRate = const Value.absent(),
    this.purchaseRate = const Value.absent(),
    this.salesRate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<StockItem> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<String>? unitOfMeasure,
    Expression<double>? openingQuantity,
    Expression<double>? openingRate,
    Expression<double>? purchaseRate,
    Expression<double>? salesRate,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (unitOfMeasure != null) 'unit_of_measure': unitOfMeasure,
      if (openingQuantity != null) 'opening_quantity': openingQuantity,
      if (openingRate != null) 'opening_rate': openingRate,
      if (purchaseRate != null) 'purchase_rate': purchaseRate,
      if (salesRate != null) 'sales_rate': salesRate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? sku,
    Value<String>? unitOfMeasure,
    Value<double>? openingQuantity,
    Value<double>? openingRate,
    Value<double>? purchaseRate,
    Value<double>? salesRate,
    Value<DateTime>? updatedAt,
    Value<bool>? isSynced,
    Value<int>? rowid,
  }) {
    return StockItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      openingQuantity: openingQuantity ?? this.openingQuantity,
      openingRate: openingRate ?? this.openingRate,
      purchaseRate: purchaseRate ?? this.purchaseRate,
      salesRate: salesRate ?? this.salesRate,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (unitOfMeasure.present) {
      map['unit_of_measure'] = Variable<String>(unitOfMeasure.value);
    }
    if (openingQuantity.present) {
      map['opening_quantity'] = Variable<double>(openingQuantity.value);
    }
    if (openingRate.present) {
      map['opening_rate'] = Variable<double>(openingRate.value);
    }
    if (purchaseRate.present) {
      map['purchase_rate'] = Variable<double>(purchaseRate.value);
    }
    if (salesRate.present) {
      map['sales_rate'] = Variable<double>(salesRate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('unitOfMeasure: $unitOfMeasure, ')
          ..write('openingQuantity: $openingQuantity, ')
          ..write('openingRate: $openingRate, ')
          ..write('purchaseRate: $purchaseRate, ')
          ..write('salesRate: $salesRate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VouchersTable extends Vouchers with TableInfo<$VouchersTable, Voucher> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VouchersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voucherNumberMeta = const VerificationMeta(
    'voucherNumber',
  );
  @override
  late final GeneratedColumn<String> voucherNumber = GeneratedColumn<String>(
    'voucher_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voucherTypeMeta = const VerificationMeta(
    'voucherType',
  );
  @override
  late final GeneratedColumn<String> voucherType = GeneratedColumn<String>(
    'voucher_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _financialYearMeta = const VerificationMeta(
    'financialYear',
  );
  @override
  late final GeneratedColumn<String> financialYear = GeneratedColumn<String>(
    'financial_year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('2025-26'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _narrationMeta = const VerificationMeta(
    'narration',
  );
  @override
  late final GeneratedColumn<String> narration = GeneratedColumn<String>(
    'narration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceNumberMeta = const VerificationMeta(
    'referenceNumber',
  );
  @override
  late final GeneratedColumn<String> referenceNumber = GeneratedColumn<String>(
    'reference_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('POSTED'),
  );
  static const VerificationMeta _discountAmountMeta = const VerificationMeta(
    'discountAmount',
  );
  @override
  late final GeneratedColumn<double> discountAmount = GeneratedColumn<double>(
    'discount_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    voucherNumber,
    voucherType,
    financialYear,
    date,
    narration,
    referenceNumber,
    status,
    discountAmount,
    updatedAt,
    isSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vouchers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Voucher> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('voucher_number')) {
      context.handle(
        _voucherNumberMeta,
        voucherNumber.isAcceptableOrUnknown(
          data['voucher_number']!,
          _voucherNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_voucherNumberMeta);
    }
    if (data.containsKey('voucher_type')) {
      context.handle(
        _voucherTypeMeta,
        voucherType.isAcceptableOrUnknown(
          data['voucher_type']!,
          _voucherTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_voucherTypeMeta);
    }
    if (data.containsKey('financial_year')) {
      context.handle(
        _financialYearMeta,
        financialYear.isAcceptableOrUnknown(
          data['financial_year']!,
          _financialYearMeta,
        ),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('narration')) {
      context.handle(
        _narrationMeta,
        narration.isAcceptableOrUnknown(data['narration']!, _narrationMeta),
      );
    }
    if (data.containsKey('reference_number')) {
      context.handle(
        _referenceNumberMeta,
        referenceNumber.isAcceptableOrUnknown(
          data['reference_number']!,
          _referenceNumberMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('discount_amount')) {
      context.handle(
        _discountAmountMeta,
        discountAmount.isAcceptableOrUnknown(
          data['discount_amount']!,
          _discountAmountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Voucher map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Voucher(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      voucherNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voucher_number'],
      )!,
      voucherType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voucher_type'],
      )!,
      financialYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}financial_year'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      narration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narration'],
      ),
      referenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_number'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      discountAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount_amount'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
    );
  }

  @override
  $VouchersTable createAlias(String alias) {
    return $VouchersTable(attachedDatabase, alias);
  }
}

class Voucher extends DataClass implements Insertable<Voucher> {
  final String id;
  final String voucherNumber;
  final String voucherType;
  final String financialYear;
  final DateTime date;
  final String? narration;
  final String? referenceNumber;
  final String status;
  final double discountAmount;
  final DateTime updatedAt;
  final bool isSynced;
  const Voucher({
    required this.id,
    required this.voucherNumber,
    required this.voucherType,
    required this.financialYear,
    required this.date,
    this.narration,
    this.referenceNumber,
    required this.status,
    required this.discountAmount,
    required this.updatedAt,
    required this.isSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['voucher_number'] = Variable<String>(voucherNumber);
    map['voucher_type'] = Variable<String>(voucherType);
    map['financial_year'] = Variable<String>(financialYear);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || narration != null) {
      map['narration'] = Variable<String>(narration);
    }
    if (!nullToAbsent || referenceNumber != null) {
      map['reference_number'] = Variable<String>(referenceNumber);
    }
    map['status'] = Variable<String>(status);
    map['discount_amount'] = Variable<double>(discountAmount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  VouchersCompanion toCompanion(bool nullToAbsent) {
    return VouchersCompanion(
      id: Value(id),
      voucherNumber: Value(voucherNumber),
      voucherType: Value(voucherType),
      financialYear: Value(financialYear),
      date: Value(date),
      narration: narration == null && nullToAbsent
          ? const Value.absent()
          : Value(narration),
      referenceNumber: referenceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceNumber),
      status: Value(status),
      discountAmount: Value(discountAmount),
      updatedAt: Value(updatedAt),
      isSynced: Value(isSynced),
    );
  }

  factory Voucher.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Voucher(
      id: serializer.fromJson<String>(json['id']),
      voucherNumber: serializer.fromJson<String>(json['voucherNumber']),
      voucherType: serializer.fromJson<String>(json['voucherType']),
      financialYear: serializer.fromJson<String>(json['financialYear']),
      date: serializer.fromJson<DateTime>(json['date']),
      narration: serializer.fromJson<String?>(json['narration']),
      referenceNumber: serializer.fromJson<String?>(json['referenceNumber']),
      status: serializer.fromJson<String>(json['status']),
      discountAmount: serializer.fromJson<double>(json['discountAmount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'voucherNumber': serializer.toJson<String>(voucherNumber),
      'voucherType': serializer.toJson<String>(voucherType),
      'financialYear': serializer.toJson<String>(financialYear),
      'date': serializer.toJson<DateTime>(date),
      'narration': serializer.toJson<String?>(narration),
      'referenceNumber': serializer.toJson<String?>(referenceNumber),
      'status': serializer.toJson<String>(status),
      'discountAmount': serializer.toJson<double>(discountAmount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  Voucher copyWith({
    String? id,
    String? voucherNumber,
    String? voucherType,
    String? financialYear,
    DateTime? date,
    Value<String?> narration = const Value.absent(),
    Value<String?> referenceNumber = const Value.absent(),
    String? status,
    double? discountAmount,
    DateTime? updatedAt,
    bool? isSynced,
  }) => Voucher(
    id: id ?? this.id,
    voucherNumber: voucherNumber ?? this.voucherNumber,
    voucherType: voucherType ?? this.voucherType,
    financialYear: financialYear ?? this.financialYear,
    date: date ?? this.date,
    narration: narration.present ? narration.value : this.narration,
    referenceNumber: referenceNumber.present
        ? referenceNumber.value
        : this.referenceNumber,
    status: status ?? this.status,
    discountAmount: discountAmount ?? this.discountAmount,
    updatedAt: updatedAt ?? this.updatedAt,
    isSynced: isSynced ?? this.isSynced,
  );
  Voucher copyWithCompanion(VouchersCompanion data) {
    return Voucher(
      id: data.id.present ? data.id.value : this.id,
      voucherNumber: data.voucherNumber.present
          ? data.voucherNumber.value
          : this.voucherNumber,
      voucherType: data.voucherType.present
          ? data.voucherType.value
          : this.voucherType,
      financialYear: data.financialYear.present
          ? data.financialYear.value
          : this.financialYear,
      date: data.date.present ? data.date.value : this.date,
      narration: data.narration.present ? data.narration.value : this.narration,
      referenceNumber: data.referenceNumber.present
          ? data.referenceNumber.value
          : this.referenceNumber,
      status: data.status.present ? data.status.value : this.status,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Voucher(')
          ..write('id: $id, ')
          ..write('voucherNumber: $voucherNumber, ')
          ..write('voucherType: $voucherType, ')
          ..write('financialYear: $financialYear, ')
          ..write('date: $date, ')
          ..write('narration: $narration, ')
          ..write('referenceNumber: $referenceNumber, ')
          ..write('status: $status, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    voucherNumber,
    voucherType,
    financialYear,
    date,
    narration,
    referenceNumber,
    status,
    discountAmount,
    updatedAt,
    isSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Voucher &&
          other.id == this.id &&
          other.voucherNumber == this.voucherNumber &&
          other.voucherType == this.voucherType &&
          other.financialYear == this.financialYear &&
          other.date == this.date &&
          other.narration == this.narration &&
          other.referenceNumber == this.referenceNumber &&
          other.status == this.status &&
          other.discountAmount == this.discountAmount &&
          other.updatedAt == this.updatedAt &&
          other.isSynced == this.isSynced);
}

class VouchersCompanion extends UpdateCompanion<Voucher> {
  final Value<String> id;
  final Value<String> voucherNumber;
  final Value<String> voucherType;
  final Value<String> financialYear;
  final Value<DateTime> date;
  final Value<String?> narration;
  final Value<String?> referenceNumber;
  final Value<String> status;
  final Value<double> discountAmount;
  final Value<DateTime> updatedAt;
  final Value<bool> isSynced;
  final Value<int> rowid;
  const VouchersCompanion({
    this.id = const Value.absent(),
    this.voucherNumber = const Value.absent(),
    this.voucherType = const Value.absent(),
    this.financialYear = const Value.absent(),
    this.date = const Value.absent(),
    this.narration = const Value.absent(),
    this.referenceNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VouchersCompanion.insert({
    required String id,
    required String voucherNumber,
    required String voucherType,
    this.financialYear = const Value.absent(),
    required DateTime date,
    this.narration = const Value.absent(),
    this.referenceNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       voucherNumber = Value(voucherNumber),
       voucherType = Value(voucherType),
       date = Value(date);
  static Insertable<Voucher> custom({
    Expression<String>? id,
    Expression<String>? voucherNumber,
    Expression<String>? voucherType,
    Expression<String>? financialYear,
    Expression<DateTime>? date,
    Expression<String>? narration,
    Expression<String>? referenceNumber,
    Expression<String>? status,
    Expression<double>? discountAmount,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voucherNumber != null) 'voucher_number': voucherNumber,
      if (voucherType != null) 'voucher_type': voucherType,
      if (financialYear != null) 'financial_year': financialYear,
      if (date != null) 'date': date,
      if (narration != null) 'narration': narration,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (status != null) 'status': status,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VouchersCompanion copyWith({
    Value<String>? id,
    Value<String>? voucherNumber,
    Value<String>? voucherType,
    Value<String>? financialYear,
    Value<DateTime>? date,
    Value<String?>? narration,
    Value<String?>? referenceNumber,
    Value<String>? status,
    Value<double>? discountAmount,
    Value<DateTime>? updatedAt,
    Value<bool>? isSynced,
    Value<int>? rowid,
  }) {
    return VouchersCompanion(
      id: id ?? this.id,
      voucherNumber: voucherNumber ?? this.voucherNumber,
      voucherType: voucherType ?? this.voucherType,
      financialYear: financialYear ?? this.financialYear,
      date: date ?? this.date,
      narration: narration ?? this.narration,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      discountAmount: discountAmount ?? this.discountAmount,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (voucherNumber.present) {
      map['voucher_number'] = Variable<String>(voucherNumber.value);
    }
    if (voucherType.present) {
      map['voucher_type'] = Variable<String>(voucherType.value);
    }
    if (financialYear.present) {
      map['financial_year'] = Variable<String>(financialYear.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (narration.present) {
      map['narration'] = Variable<String>(narration.value);
    }
    if (referenceNumber.present) {
      map['reference_number'] = Variable<String>(referenceNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<double>(discountAmount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VouchersCompanion(')
          ..write('id: $id, ')
          ..write('voucherNumber: $voucherNumber, ')
          ..write('voucherType: $voucherType, ')
          ..write('financialYear: $financialYear, ')
          ..write('date: $date, ')
          ..write('narration: $narration, ')
          ..write('referenceNumber: $referenceNumber, ')
          ..write('status: $status, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoucherEntriesTable extends VoucherEntries
    with TableInfo<$VoucherEntriesTable, VoucherEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoucherEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voucherIdMeta = const VerificationMeta(
    'voucherId',
  );
  @override
  late final GeneratedColumn<String> voucherId = GeneratedColumn<String>(
    'voucher_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _debitAmountMeta = const VerificationMeta(
    'debitAmount',
  );
  @override
  late final GeneratedColumn<double> debitAmount = GeneratedColumn<double>(
    'debit_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _creditAmountMeta = const VerificationMeta(
    'creditAmount',
  );
  @override
  late final GeneratedColumn<double> creditAmount = GeneratedColumn<double>(
    'credit_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    voucherId,
    ledgerId,
    debitAmount,
    creditAmount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voucher_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoucherEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('voucher_id')) {
      context.handle(
        _voucherIdMeta,
        voucherId.isAcceptableOrUnknown(data['voucher_id']!, _voucherIdMeta),
      );
    } else if (isInserting) {
      context.missing(_voucherIdMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('debit_amount')) {
      context.handle(
        _debitAmountMeta,
        debitAmount.isAcceptableOrUnknown(
          data['debit_amount']!,
          _debitAmountMeta,
        ),
      );
    }
    if (data.containsKey('credit_amount')) {
      context.handle(
        _creditAmountMeta,
        creditAmount.isAcceptableOrUnknown(
          data['credit_amount']!,
          _creditAmountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoucherEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoucherEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      voucherId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voucher_id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      debitAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}debit_amount'],
      )!,
      creditAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}credit_amount'],
      )!,
    );
  }

  @override
  $VoucherEntriesTable createAlias(String alias) {
    return $VoucherEntriesTable(attachedDatabase, alias);
  }
}

class VoucherEntry extends DataClass implements Insertable<VoucherEntry> {
  final String id;
  final String voucherId;
  final String ledgerId;
  final double debitAmount;
  final double creditAmount;
  const VoucherEntry({
    required this.id,
    required this.voucherId,
    required this.ledgerId,
    required this.debitAmount,
    required this.creditAmount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['voucher_id'] = Variable<String>(voucherId);
    map['ledger_id'] = Variable<String>(ledgerId);
    map['debit_amount'] = Variable<double>(debitAmount);
    map['credit_amount'] = Variable<double>(creditAmount);
    return map;
  }

  VoucherEntriesCompanion toCompanion(bool nullToAbsent) {
    return VoucherEntriesCompanion(
      id: Value(id),
      voucherId: Value(voucherId),
      ledgerId: Value(ledgerId),
      debitAmount: Value(debitAmount),
      creditAmount: Value(creditAmount),
    );
  }

  factory VoucherEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoucherEntry(
      id: serializer.fromJson<String>(json['id']),
      voucherId: serializer.fromJson<String>(json['voucherId']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      debitAmount: serializer.fromJson<double>(json['debitAmount']),
      creditAmount: serializer.fromJson<double>(json['creditAmount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'voucherId': serializer.toJson<String>(voucherId),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'debitAmount': serializer.toJson<double>(debitAmount),
      'creditAmount': serializer.toJson<double>(creditAmount),
    };
  }

  VoucherEntry copyWith({
    String? id,
    String? voucherId,
    String? ledgerId,
    double? debitAmount,
    double? creditAmount,
  }) => VoucherEntry(
    id: id ?? this.id,
    voucherId: voucherId ?? this.voucherId,
    ledgerId: ledgerId ?? this.ledgerId,
    debitAmount: debitAmount ?? this.debitAmount,
    creditAmount: creditAmount ?? this.creditAmount,
  );
  VoucherEntry copyWithCompanion(VoucherEntriesCompanion data) {
    return VoucherEntry(
      id: data.id.present ? data.id.value : this.id,
      voucherId: data.voucherId.present ? data.voucherId.value : this.voucherId,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      debitAmount: data.debitAmount.present
          ? data.debitAmount.value
          : this.debitAmount,
      creditAmount: data.creditAmount.present
          ? data.creditAmount.value
          : this.creditAmount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoucherEntry(')
          ..write('id: $id, ')
          ..write('voucherId: $voucherId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('debitAmount: $debitAmount, ')
          ..write('creditAmount: $creditAmount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, voucherId, ledgerId, debitAmount, creditAmount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoucherEntry &&
          other.id == this.id &&
          other.voucherId == this.voucherId &&
          other.ledgerId == this.ledgerId &&
          other.debitAmount == this.debitAmount &&
          other.creditAmount == this.creditAmount);
}

class VoucherEntriesCompanion extends UpdateCompanion<VoucherEntry> {
  final Value<String> id;
  final Value<String> voucherId;
  final Value<String> ledgerId;
  final Value<double> debitAmount;
  final Value<double> creditAmount;
  final Value<int> rowid;
  const VoucherEntriesCompanion({
    this.id = const Value.absent(),
    this.voucherId = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.debitAmount = const Value.absent(),
    this.creditAmount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoucherEntriesCompanion.insert({
    required String id,
    required String voucherId,
    required String ledgerId,
    this.debitAmount = const Value.absent(),
    this.creditAmount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       voucherId = Value(voucherId),
       ledgerId = Value(ledgerId);
  static Insertable<VoucherEntry> custom({
    Expression<String>? id,
    Expression<String>? voucherId,
    Expression<String>? ledgerId,
    Expression<double>? debitAmount,
    Expression<double>? creditAmount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voucherId != null) 'voucher_id': voucherId,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (debitAmount != null) 'debit_amount': debitAmount,
      if (creditAmount != null) 'credit_amount': creditAmount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoucherEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? voucherId,
    Value<String>? ledgerId,
    Value<double>? debitAmount,
    Value<double>? creditAmount,
    Value<int>? rowid,
  }) {
    return VoucherEntriesCompanion(
      id: id ?? this.id,
      voucherId: voucherId ?? this.voucherId,
      ledgerId: ledgerId ?? this.ledgerId,
      debitAmount: debitAmount ?? this.debitAmount,
      creditAmount: creditAmount ?? this.creditAmount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (voucherId.present) {
      map['voucher_id'] = Variable<String>(voucherId.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (debitAmount.present) {
      map['debit_amount'] = Variable<double>(debitAmount.value);
    }
    if (creditAmount.present) {
      map['credit_amount'] = Variable<double>(creditAmount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoucherEntriesCompanion(')
          ..write('id: $id, ')
          ..write('voucherId: $voucherId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('debitAmount: $debitAmount, ')
          ..write('creditAmount: $creditAmount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockTransactionsTable extends StockTransactions
    with TableInfo<$StockTransactionsTable, StockTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voucherIdMeta = const VerificationMeta(
    'voucherId',
  );
  @override
  late final GeneratedColumn<String> voucherId = GeneratedColumn<String>(
    'voucher_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stockItemIdMeta = const VerificationMeta(
    'stockItemId',
  );
  @override
  late final GeneratedColumn<String> stockItemId = GeneratedColumn<String>(
    'stock_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<double> rate = GeneratedColumn<double>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionTypeMeta = const VerificationMeta(
    'transactionType',
  );
  @override
  late final GeneratedColumn<String> transactionType = GeneratedColumn<String>(
    'transaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReplacementMeta = const VerificationMeta(
    'isReplacement',
  );
  @override
  late final GeneratedColumn<bool> isReplacement = GeneratedColumn<bool>(
    'is_replacement',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_replacement" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    voucherId,
    stockItemId,
    quantity,
    rate,
    transactionType,
    isReplacement,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('voucher_id')) {
      context.handle(
        _voucherIdMeta,
        voucherId.isAcceptableOrUnknown(data['voucher_id']!, _voucherIdMeta),
      );
    } else if (isInserting) {
      context.missing(_voucherIdMeta);
    }
    if (data.containsKey('stock_item_id')) {
      context.handle(
        _stockItemIdMeta,
        stockItemId.isAcceptableOrUnknown(
          data['stock_item_id']!,
          _stockItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stockItemIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('transaction_type')) {
      context.handle(
        _transactionTypeMeta,
        transactionType.isAcceptableOrUnknown(
          data['transaction_type']!,
          _transactionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionTypeMeta);
    }
    if (data.containsKey('is_replacement')) {
      context.handle(
        _isReplacementMeta,
        isReplacement.isAcceptableOrUnknown(
          data['is_replacement']!,
          _isReplacementMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      voucherId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voucher_id'],
      )!,
      stockItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_item_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate'],
      )!,
      transactionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_type'],
      )!,
      isReplacement: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_replacement'],
      )!,
    );
  }

  @override
  $StockTransactionsTable createAlias(String alias) {
    return $StockTransactionsTable(attachedDatabase, alias);
  }
}

class StockTransaction extends DataClass
    implements Insertable<StockTransaction> {
  final String id;
  final String voucherId;
  final String stockItemId;
  final double quantity;
  final double rate;
  final String transactionType;
  final bool isReplacement;
  const StockTransaction({
    required this.id,
    required this.voucherId,
    required this.stockItemId,
    required this.quantity,
    required this.rate,
    required this.transactionType,
    required this.isReplacement,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['voucher_id'] = Variable<String>(voucherId);
    map['stock_item_id'] = Variable<String>(stockItemId);
    map['quantity'] = Variable<double>(quantity);
    map['rate'] = Variable<double>(rate);
    map['transaction_type'] = Variable<String>(transactionType);
    map['is_replacement'] = Variable<bool>(isReplacement);
    return map;
  }

  StockTransactionsCompanion toCompanion(bool nullToAbsent) {
    return StockTransactionsCompanion(
      id: Value(id),
      voucherId: Value(voucherId),
      stockItemId: Value(stockItemId),
      quantity: Value(quantity),
      rate: Value(rate),
      transactionType: Value(transactionType),
      isReplacement: Value(isReplacement),
    );
  }

  factory StockTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockTransaction(
      id: serializer.fromJson<String>(json['id']),
      voucherId: serializer.fromJson<String>(json['voucherId']),
      stockItemId: serializer.fromJson<String>(json['stockItemId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      rate: serializer.fromJson<double>(json['rate']),
      transactionType: serializer.fromJson<String>(json['transactionType']),
      isReplacement: serializer.fromJson<bool>(json['isReplacement']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'voucherId': serializer.toJson<String>(voucherId),
      'stockItemId': serializer.toJson<String>(stockItemId),
      'quantity': serializer.toJson<double>(quantity),
      'rate': serializer.toJson<double>(rate),
      'transactionType': serializer.toJson<String>(transactionType),
      'isReplacement': serializer.toJson<bool>(isReplacement),
    };
  }

  StockTransaction copyWith({
    String? id,
    String? voucherId,
    String? stockItemId,
    double? quantity,
    double? rate,
    String? transactionType,
    bool? isReplacement,
  }) => StockTransaction(
    id: id ?? this.id,
    voucherId: voucherId ?? this.voucherId,
    stockItemId: stockItemId ?? this.stockItemId,
    quantity: quantity ?? this.quantity,
    rate: rate ?? this.rate,
    transactionType: transactionType ?? this.transactionType,
    isReplacement: isReplacement ?? this.isReplacement,
  );
  StockTransaction copyWithCompanion(StockTransactionsCompanion data) {
    return StockTransaction(
      id: data.id.present ? data.id.value : this.id,
      voucherId: data.voucherId.present ? data.voucherId.value : this.voucherId,
      stockItemId: data.stockItemId.present
          ? data.stockItemId.value
          : this.stockItemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      rate: data.rate.present ? data.rate.value : this.rate,
      transactionType: data.transactionType.present
          ? data.transactionType.value
          : this.transactionType,
      isReplacement: data.isReplacement.present
          ? data.isReplacement.value
          : this.isReplacement,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockTransaction(')
          ..write('id: $id, ')
          ..write('voucherId: $voucherId, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('quantity: $quantity, ')
          ..write('rate: $rate, ')
          ..write('transactionType: $transactionType, ')
          ..write('isReplacement: $isReplacement')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    voucherId,
    stockItemId,
    quantity,
    rate,
    transactionType,
    isReplacement,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockTransaction &&
          other.id == this.id &&
          other.voucherId == this.voucherId &&
          other.stockItemId == this.stockItemId &&
          other.quantity == this.quantity &&
          other.rate == this.rate &&
          other.transactionType == this.transactionType &&
          other.isReplacement == this.isReplacement);
}

class StockTransactionsCompanion extends UpdateCompanion<StockTransaction> {
  final Value<String> id;
  final Value<String> voucherId;
  final Value<String> stockItemId;
  final Value<double> quantity;
  final Value<double> rate;
  final Value<String> transactionType;
  final Value<bool> isReplacement;
  final Value<int> rowid;
  const StockTransactionsCompanion({
    this.id = const Value.absent(),
    this.voucherId = const Value.absent(),
    this.stockItemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rate = const Value.absent(),
    this.transactionType = const Value.absent(),
    this.isReplacement = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockTransactionsCompanion.insert({
    required String id,
    required String voucherId,
    required String stockItemId,
    required double quantity,
    required double rate,
    required String transactionType,
    this.isReplacement = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       voucherId = Value(voucherId),
       stockItemId = Value(stockItemId),
       quantity = Value(quantity),
       rate = Value(rate),
       transactionType = Value(transactionType);
  static Insertable<StockTransaction> custom({
    Expression<String>? id,
    Expression<String>? voucherId,
    Expression<String>? stockItemId,
    Expression<double>? quantity,
    Expression<double>? rate,
    Expression<String>? transactionType,
    Expression<bool>? isReplacement,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voucherId != null) 'voucher_id': voucherId,
      if (stockItemId != null) 'stock_item_id': stockItemId,
      if (quantity != null) 'quantity': quantity,
      if (rate != null) 'rate': rate,
      if (transactionType != null) 'transaction_type': transactionType,
      if (isReplacement != null) 'is_replacement': isReplacement,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? voucherId,
    Value<String>? stockItemId,
    Value<double>? quantity,
    Value<double>? rate,
    Value<String>? transactionType,
    Value<bool>? isReplacement,
    Value<int>? rowid,
  }) {
    return StockTransactionsCompanion(
      id: id ?? this.id,
      voucherId: voucherId ?? this.voucherId,
      stockItemId: stockItemId ?? this.stockItemId,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      transactionType: transactionType ?? this.transactionType,
      isReplacement: isReplacement ?? this.isReplacement,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (voucherId.present) {
      map['voucher_id'] = Variable<String>(voucherId.value);
    }
    if (stockItemId.present) {
      map['stock_item_id'] = Variable<String>(stockItemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (rate.present) {
      map['rate'] = Variable<double>(rate.value);
    }
    if (transactionType.present) {
      map['transaction_type'] = Variable<String>(transactionType.value);
    }
    if (isReplacement.present) {
      map['is_replacement'] = Variable<bool>(isReplacement.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('voucherId: $voucherId, ')
          ..write('stockItemId: $stockItemId, ')
          ..write('quantity: $quantity, ')
          ..write('rate: $rate, ')
          ..write('transactionType: $transactionType, ')
          ..write('isReplacement: $isReplacement, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetadataData copyWith({String? key, String? value}) =>
      SyncMetadataData(key: key ?? this.key, value: value ?? this.value);
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvoiceSequencesTable extends InvoiceSequences
    with TableInfo<$InvoiceSequencesTable, InvoiceSequence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoiceSequencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _financialYearMeta = const VerificationMeta(
    'financialYear',
  );
  @override
  late final GeneratedColumn<String> financialYear = GeneratedColumn<String>(
    'financial_year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voucherTypeMeta = const VerificationMeta(
    'voucherType',
  );
  @override
  late final GeneratedColumn<String> voucherType = GeneratedColumn<String>(
    'voucher_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextNumberMeta = const VerificationMeta(
    'nextNumber',
  );
  @override
  late final GeneratedColumn<int> nextNumber = GeneratedColumn<int>(
    'next_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    financialYear,
    voucherType,
    nextNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoice_sequences';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvoiceSequence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('financial_year')) {
      context.handle(
        _financialYearMeta,
        financialYear.isAcceptableOrUnknown(
          data['financial_year']!,
          _financialYearMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_financialYearMeta);
    }
    if (data.containsKey('voucher_type')) {
      context.handle(
        _voucherTypeMeta,
        voucherType.isAcceptableOrUnknown(
          data['voucher_type']!,
          _voucherTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_voucherTypeMeta);
    }
    if (data.containsKey('next_number')) {
      context.handle(
        _nextNumberMeta,
        nextNumber.isAcceptableOrUnknown(data['next_number']!, _nextNumberMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceSequence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceSequence(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      financialYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}financial_year'],
      )!,
      voucherType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voucher_type'],
      )!,
      nextNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_number'],
      )!,
    );
  }

  @override
  $InvoiceSequencesTable createAlias(String alias) {
    return $InvoiceSequencesTable(attachedDatabase, alias);
  }
}

class InvoiceSequence extends DataClass implements Insertable<InvoiceSequence> {
  final String id;
  final String financialYear;
  final String voucherType;
  final int nextNumber;
  const InvoiceSequence({
    required this.id,
    required this.financialYear,
    required this.voucherType,
    required this.nextNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['financial_year'] = Variable<String>(financialYear);
    map['voucher_type'] = Variable<String>(voucherType);
    map['next_number'] = Variable<int>(nextNumber);
    return map;
  }

  InvoiceSequencesCompanion toCompanion(bool nullToAbsent) {
    return InvoiceSequencesCompanion(
      id: Value(id),
      financialYear: Value(financialYear),
      voucherType: Value(voucherType),
      nextNumber: Value(nextNumber),
    );
  }

  factory InvoiceSequence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceSequence(
      id: serializer.fromJson<String>(json['id']),
      financialYear: serializer.fromJson<String>(json['financialYear']),
      voucherType: serializer.fromJson<String>(json['voucherType']),
      nextNumber: serializer.fromJson<int>(json['nextNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'financialYear': serializer.toJson<String>(financialYear),
      'voucherType': serializer.toJson<String>(voucherType),
      'nextNumber': serializer.toJson<int>(nextNumber),
    };
  }

  InvoiceSequence copyWith({
    String? id,
    String? financialYear,
    String? voucherType,
    int? nextNumber,
  }) => InvoiceSequence(
    id: id ?? this.id,
    financialYear: financialYear ?? this.financialYear,
    voucherType: voucherType ?? this.voucherType,
    nextNumber: nextNumber ?? this.nextNumber,
  );
  InvoiceSequence copyWithCompanion(InvoiceSequencesCompanion data) {
    return InvoiceSequence(
      id: data.id.present ? data.id.value : this.id,
      financialYear: data.financialYear.present
          ? data.financialYear.value
          : this.financialYear,
      voucherType: data.voucherType.present
          ? data.voucherType.value
          : this.voucherType,
      nextNumber: data.nextNumber.present
          ? data.nextNumber.value
          : this.nextNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceSequence(')
          ..write('id: $id, ')
          ..write('financialYear: $financialYear, ')
          ..write('voucherType: $voucherType, ')
          ..write('nextNumber: $nextNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, financialYear, voucherType, nextNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceSequence &&
          other.id == this.id &&
          other.financialYear == this.financialYear &&
          other.voucherType == this.voucherType &&
          other.nextNumber == this.nextNumber);
}

class InvoiceSequencesCompanion extends UpdateCompanion<InvoiceSequence> {
  final Value<String> id;
  final Value<String> financialYear;
  final Value<String> voucherType;
  final Value<int> nextNumber;
  final Value<int> rowid;
  const InvoiceSequencesCompanion({
    this.id = const Value.absent(),
    this.financialYear = const Value.absent(),
    this.voucherType = const Value.absent(),
    this.nextNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvoiceSequencesCompanion.insert({
    required String id,
    required String financialYear,
    required String voucherType,
    this.nextNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       financialYear = Value(financialYear),
       voucherType = Value(voucherType);
  static Insertable<InvoiceSequence> custom({
    Expression<String>? id,
    Expression<String>? financialYear,
    Expression<String>? voucherType,
    Expression<int>? nextNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (financialYear != null) 'financial_year': financialYear,
      if (voucherType != null) 'voucher_type': voucherType,
      if (nextNumber != null) 'next_number': nextNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvoiceSequencesCompanion copyWith({
    Value<String>? id,
    Value<String>? financialYear,
    Value<String>? voucherType,
    Value<int>? nextNumber,
    Value<int>? rowid,
  }) {
    return InvoiceSequencesCompanion(
      id: id ?? this.id,
      financialYear: financialYear ?? this.financialYear,
      voucherType: voucherType ?? this.voucherType,
      nextNumber: nextNumber ?? this.nextNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (financialYear.present) {
      map['financial_year'] = Variable<String>(financialYear.value);
    }
    if (voucherType.present) {
      map['voucher_type'] = Variable<String>(voucherType.value);
    }
    if (nextNumber.present) {
      map['next_number'] = Variable<int>(nextNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceSequencesCompanion(')
          ..write('id: $id, ')
          ..write('financialYear: $financialYear, ')
          ..write('voucherType: $voucherType, ')
          ..write('nextNumber: $nextNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _userDeviceMeta = const VerificationMeta(
    'userDevice',
  );
  @override
  late final GeneratedColumn<String> userDevice = GeneratedColumn<String>(
    'user_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Desktop'),
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  @override
  late final GeneratedColumn<String> oldValue = GeneratedColumn<String>(
    'old_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  @override
  late final GeneratedColumn<String> newValue = GeneratedColumn<String>(
    'new_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    userDevice,
    action,
    entityType,
    entityId,
    oldValue,
    newValue,
    metadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('user_device')) {
      context.handle(
        _userDeviceMeta,
        userDevice.isAcceptableOrUnknown(data['user_device']!, _userDeviceMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      userDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_device'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_value'],
      ),
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_value'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final String id;
  final DateTime timestamp;
  final String userDevice;
  final String action;
  final String entityType;
  final String entityId;
  final String? oldValue;
  final String? newValue;
  final String? metadata;
  const AuditLog({
    required this.id,
    required this.timestamp,
    required this.userDevice,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValue,
    this.newValue,
    this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['user_device'] = Variable<String>(userDevice);
    map['action'] = Variable<String>(action);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || oldValue != null) {
      map['old_value'] = Variable<String>(oldValue);
    }
    if (!nullToAbsent || newValue != null) {
      map['new_value'] = Variable<String>(newValue);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      userDevice: Value(userDevice),
      action: Value(action),
      entityType: Value(entityType),
      entityId: Value(entityId),
      oldValue: oldValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldValue),
      newValue: newValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newValue),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
    );
  }

  factory AuditLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      userDevice: serializer.fromJson<String>(json['userDevice']),
      action: serializer.fromJson<String>(json['action']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      oldValue: serializer.fromJson<String?>(json['oldValue']),
      newValue: serializer.fromJson<String?>(json['newValue']),
      metadata: serializer.fromJson<String?>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'userDevice': serializer.toJson<String>(userDevice),
      'action': serializer.toJson<String>(action),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'oldValue': serializer.toJson<String?>(oldValue),
      'newValue': serializer.toJson<String?>(newValue),
      'metadata': serializer.toJson<String?>(metadata),
    };
  }

  AuditLog copyWith({
    String? id,
    DateTime? timestamp,
    String? userDevice,
    String? action,
    String? entityType,
    String? entityId,
    Value<String?> oldValue = const Value.absent(),
    Value<String?> newValue = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
  }) => AuditLog(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    userDevice: userDevice ?? this.userDevice,
    action: action ?? this.action,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    oldValue: oldValue.present ? oldValue.value : this.oldValue,
    newValue: newValue.present ? newValue.value : this.newValue,
    metadata: metadata.present ? metadata.value : this.metadata,
  );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      userDevice: data.userDevice.present
          ? data.userDevice.value
          : this.userDevice,
      action: data.action.present ? data.action.value : this.action,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      oldValue: data.oldValue.present ? data.oldValue.value : this.oldValue,
      newValue: data.newValue.present ? data.newValue.value : this.newValue,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('userDevice: $userDevice, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    userDevice,
    action,
    entityType,
    entityId,
    oldValue,
    newValue,
    metadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.userDevice == this.userDevice &&
          other.action == this.action &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.oldValue == this.oldValue &&
          other.newValue == this.newValue &&
          other.metadata == this.metadata);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<String> userDevice;
  final Value<String> action;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String?> oldValue;
  final Value<String?> newValue;
  final Value<String?> metadata;
  final Value<int> rowid;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.userDevice = const Value.absent(),
    this.action = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    required String id,
    this.timestamp = const Value.absent(),
    this.userDevice = const Value.absent(),
    required String action,
    required String entityType,
    required String entityId,
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       action = Value(action),
       entityType = Value(entityType),
       entityId = Value(entityId);
  static Insertable<AuditLog> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? userDevice,
    Expression<String>? action,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? oldValue,
    Expression<String>? newValue,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (userDevice != null) 'user_device': userDevice,
      if (action != null) 'action': action,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? timestamp,
    Value<String>? userDevice,
    Value<String>? action,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String?>? oldValue,
    Value<String?>? newValue,
    Value<String?>? metadata,
    Value<int>? rowid,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      userDevice: userDevice ?? this.userDevice,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (userDevice.present) {
      map['user_device'] = Variable<String>(userDevice.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<String>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<String>(newValue.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('userDevice: $userDevice, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BusinessProfilesTable extends BusinessProfiles
    with TableInfo<$BusinessProfilesTable, BusinessProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyNameMeta = const VerificationMeta(
    'companyName',
  );
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
    'company_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxNumberMeta = const VerificationMeta(
    'taxNumber',
  );
  @override
  late final GeneratedColumn<String> taxNumber = GeneratedColumn<String>(
    'tax_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bankDetailsMeta = const VerificationMeta(
    'bankDetails',
  );
  @override
  late final GeneratedColumn<String> bankDetails = GeneratedColumn<String>(
    'bank_details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _termsAndConditionsMeta =
      const VerificationMeta('termsAndConditions');
  @override
  late final GeneratedColumn<String> termsAndConditions =
      GeneratedColumn<String>(
        'terms_and_conditions',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _logoPathMeta = const VerificationMeta(
    'logoPath',
  );
  @override
  late final GeneratedColumn<String> logoPath = GeneratedColumn<String>(
    'logo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyName,
    address,
    phone,
    email,
    taxNumber,
    bankDetails,
    termsAndConditions,
    logoPath,
    isActive,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'business_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<BusinessProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_name')) {
      context.handle(
        _companyNameMeta,
        companyName.isAcceptableOrUnknown(
          data['company_name']!,
          _companyNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_companyNameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('tax_number')) {
      context.handle(
        _taxNumberMeta,
        taxNumber.isAcceptableOrUnknown(data['tax_number']!, _taxNumberMeta),
      );
    }
    if (data.containsKey('bank_details')) {
      context.handle(
        _bankDetailsMeta,
        bankDetails.isAcceptableOrUnknown(
          data['bank_details']!,
          _bankDetailsMeta,
        ),
      );
    }
    if (data.containsKey('terms_and_conditions')) {
      context.handle(
        _termsAndConditionsMeta,
        termsAndConditions.isAcceptableOrUnknown(
          data['terms_and_conditions']!,
          _termsAndConditionsMeta,
        ),
      );
    }
    if (data.containsKey('logo_path')) {
      context.handle(
        _logoPathMeta,
        logoPath.isAcceptableOrUnknown(data['logo_path']!, _logoPathMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BusinessProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BusinessProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      taxNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_number'],
      ),
      bankDetails: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_details'],
      ),
      termsAndConditions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}terms_and_conditions'],
      ),
      logoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_path'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BusinessProfilesTable createAlias(String alias) {
    return $BusinessProfilesTable(attachedDatabase, alias);
  }
}

class BusinessProfile extends DataClass implements Insertable<BusinessProfile> {
  final String id;
  final String companyName;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxNumber;
  final String? bankDetails;
  final String? termsAndConditions;
  final String? logoPath;
  final bool isActive;
  final DateTime updatedAt;
  const BusinessProfile({
    required this.id,
    required this.companyName,
    this.address,
    this.phone,
    this.email,
    this.taxNumber,
    this.bankDetails,
    this.termsAndConditions,
    this.logoPath,
    required this.isActive,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_name'] = Variable<String>(companyName);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || taxNumber != null) {
      map['tax_number'] = Variable<String>(taxNumber);
    }
    if (!nullToAbsent || bankDetails != null) {
      map['bank_details'] = Variable<String>(bankDetails);
    }
    if (!nullToAbsent || termsAndConditions != null) {
      map['terms_and_conditions'] = Variable<String>(termsAndConditions);
    }
    if (!nullToAbsent || logoPath != null) {
      map['logo_path'] = Variable<String>(logoPath);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BusinessProfilesCompanion toCompanion(bool nullToAbsent) {
    return BusinessProfilesCompanion(
      id: Value(id),
      companyName: Value(companyName),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      taxNumber: taxNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(taxNumber),
      bankDetails: bankDetails == null && nullToAbsent
          ? const Value.absent()
          : Value(bankDetails),
      termsAndConditions: termsAndConditions == null && nullToAbsent
          ? const Value.absent()
          : Value(termsAndConditions),
      logoPath: logoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(logoPath),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
    );
  }

  factory BusinessProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessProfile(
      id: serializer.fromJson<String>(json['id']),
      companyName: serializer.fromJson<String>(json['companyName']),
      address: serializer.fromJson<String?>(json['address']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      taxNumber: serializer.fromJson<String?>(json['taxNumber']),
      bankDetails: serializer.fromJson<String?>(json['bankDetails']),
      termsAndConditions: serializer.fromJson<String?>(
        json['termsAndConditions'],
      ),
      logoPath: serializer.fromJson<String?>(json['logoPath']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyName': serializer.toJson<String>(companyName),
      'address': serializer.toJson<String?>(address),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'taxNumber': serializer.toJson<String?>(taxNumber),
      'bankDetails': serializer.toJson<String?>(bankDetails),
      'termsAndConditions': serializer.toJson<String?>(termsAndConditions),
      'logoPath': serializer.toJson<String?>(logoPath),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BusinessProfile copyWith({
    String? id,
    String? companyName,
    Value<String?> address = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> taxNumber = const Value.absent(),
    Value<String?> bankDetails = const Value.absent(),
    Value<String?> termsAndConditions = const Value.absent(),
    Value<String?> logoPath = const Value.absent(),
    bool? isActive,
    DateTime? updatedAt,
  }) => BusinessProfile(
    id: id ?? this.id,
    companyName: companyName ?? this.companyName,
    address: address.present ? address.value : this.address,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    taxNumber: taxNumber.present ? taxNumber.value : this.taxNumber,
    bankDetails: bankDetails.present ? bankDetails.value : this.bankDetails,
    termsAndConditions: termsAndConditions.present
        ? termsAndConditions.value
        : this.termsAndConditions,
    logoPath: logoPath.present ? logoPath.value : this.logoPath,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BusinessProfile copyWithCompanion(BusinessProfilesCompanion data) {
    return BusinessProfile(
      id: data.id.present ? data.id.value : this.id,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      address: data.address.present ? data.address.value : this.address,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      taxNumber: data.taxNumber.present ? data.taxNumber.value : this.taxNumber,
      bankDetails: data.bankDetails.present
          ? data.bankDetails.value
          : this.bankDetails,
      termsAndConditions: data.termsAndConditions.present
          ? data.termsAndConditions.value
          : this.termsAndConditions,
      logoPath: data.logoPath.present ? data.logoPath.value : this.logoPath,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessProfile(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('bankDetails: $bankDetails, ')
          ..write('termsAndConditions: $termsAndConditions, ')
          ..write('logoPath: $logoPath, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyName,
    address,
    phone,
    email,
    taxNumber,
    bankDetails,
    termsAndConditions,
    logoPath,
    isActive,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessProfile &&
          other.id == this.id &&
          other.companyName == this.companyName &&
          other.address == this.address &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.taxNumber == this.taxNumber &&
          other.bankDetails == this.bankDetails &&
          other.termsAndConditions == this.termsAndConditions &&
          other.logoPath == this.logoPath &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt);
}

class BusinessProfilesCompanion extends UpdateCompanion<BusinessProfile> {
  final Value<String> id;
  final Value<String> companyName;
  final Value<String?> address;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> taxNumber;
  final Value<String?> bankDetails;
  final Value<String?> termsAndConditions;
  final Value<String?> logoPath;
  final Value<bool> isActive;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BusinessProfilesCompanion({
    this.id = const Value.absent(),
    this.companyName = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.bankDetails = const Value.absent(),
    this.termsAndConditions = const Value.absent(),
    this.logoPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BusinessProfilesCompanion.insert({
    required String id,
    required String companyName,
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.bankDetails = const Value.absent(),
    this.termsAndConditions = const Value.absent(),
    this.logoPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyName = Value(companyName);
  static Insertable<BusinessProfile> custom({
    Expression<String>? id,
    Expression<String>? companyName,
    Expression<String>? address,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? taxNumber,
    Expression<String>? bankDetails,
    Expression<String>? termsAndConditions,
    Expression<String>? logoPath,
    Expression<bool>? isActive,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyName != null) 'company_name': companyName,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (taxNumber != null) 'tax_number': taxNumber,
      if (bankDetails != null) 'bank_details': bankDetails,
      if (termsAndConditions != null)
        'terms_and_conditions': termsAndConditions,
      if (logoPath != null) 'logo_path': logoPath,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BusinessProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyName,
    Value<String?>? address,
    Value<String?>? phone,
    Value<String?>? email,
    Value<String?>? taxNumber,
    Value<String?>? bankDetails,
    Value<String?>? termsAndConditions,
    Value<String?>? logoPath,
    Value<bool>? isActive,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BusinessProfilesCompanion(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      bankDetails: bankDetails ?? this.bankDetails,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      logoPath: logoPath ?? this.logoPath,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyName.present) {
      map['company_name'] = Variable<String>(companyName.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (taxNumber.present) {
      map['tax_number'] = Variable<String>(taxNumber.value);
    }
    if (bankDetails.present) {
      map['bank_details'] = Variable<String>(bankDetails.value);
    }
    if (termsAndConditions.present) {
      map['terms_and_conditions'] = Variable<String>(termsAndConditions.value);
    }
    if (logoPath.present) {
      map['logo_path'] = Variable<String>(logoPath.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessProfilesCompanion(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('bankDetails: $bankDetails, ')
          ..write('termsAndConditions: $termsAndConditions, ')
          ..write('logoPath: $logoPath, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountGroupsTable accountGroups = $AccountGroupsTable(this);
  late final $LedgersTable ledgers = $LedgersTable(this);
  late final $StockItemsTable stockItems = $StockItemsTable(this);
  late final $VouchersTable vouchers = $VouchersTable(this);
  late final $VoucherEntriesTable voucherEntries = $VoucherEntriesTable(this);
  late final $StockTransactionsTable stockTransactions =
      $StockTransactionsTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  late final $InvoiceSequencesTable invoiceSequences = $InvoiceSequencesTable(
    this,
  );
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $BusinessProfilesTable businessProfiles = $BusinessProfilesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accountGroups,
    ledgers,
    stockItems,
    vouchers,
    voucherEntries,
    stockTransactions,
    syncMetadata,
    invoiceSequences,
    auditLogs,
    businessProfiles,
  ];
}

typedef $$AccountGroupsTableCreateCompanionBuilder =
    AccountGroupsCompanion Function({
      required String id,
      required String name,
      required String primaryGroup,
      Value<int> rowid,
    });
typedef $$AccountGroupsTableUpdateCompanionBuilder =
    AccountGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> primaryGroup,
      Value<int> rowid,
    });

class $$AccountGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountGroupsTable> {
  $$AccountGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryGroup => $composableBuilder(
    column: $table.primaryGroup,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountGroupsTable> {
  $$AccountGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryGroup => $composableBuilder(
    column: $table.primaryGroup,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountGroupsTable> {
  $$AccountGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get primaryGroup => $composableBuilder(
    column: $table.primaryGroup,
    builder: (column) => column,
  );
}

class $$AccountGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountGroupsTable,
          AccountGroup,
          $$AccountGroupsTableFilterComposer,
          $$AccountGroupsTableOrderingComposer,
          $$AccountGroupsTableAnnotationComposer,
          $$AccountGroupsTableCreateCompanionBuilder,
          $$AccountGroupsTableUpdateCompanionBuilder,
          (
            AccountGroup,
            BaseReferences<_$AppDatabase, $AccountGroupsTable, AccountGroup>,
          ),
          AccountGroup,
          PrefetchHooks Function()
        > {
  $$AccountGroupsTableTableManager(_$AppDatabase db, $AccountGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> primaryGroup = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountGroupsCompanion(
                id: id,
                name: name,
                primaryGroup: primaryGroup,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String primaryGroup,
                Value<int> rowid = const Value.absent(),
              }) => AccountGroupsCompanion.insert(
                id: id,
                name: name,
                primaryGroup: primaryGroup,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountGroupsTable,
      AccountGroup,
      $$AccountGroupsTableFilterComposer,
      $$AccountGroupsTableOrderingComposer,
      $$AccountGroupsTableAnnotationComposer,
      $$AccountGroupsTableCreateCompanionBuilder,
      $$AccountGroupsTableUpdateCompanionBuilder,
      (
        AccountGroup,
        BaseReferences<_$AppDatabase, $AccountGroupsTable, AccountGroup>,
      ),
      AccountGroup,
      PrefetchHooks Function()
    >;
typedef $$LedgersTableCreateCompanionBuilder =
    LedgersCompanion Function({
      required String id,
      required String name,
      required String groupId,
      Value<double> openingBalance,
      Value<String?> phone,
      Value<String?> address,
      Value<String?> email,
      Value<String?> taxNumber,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$LedgersTableUpdateCompanionBuilder =
    LedgersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> groupId,
      Value<double> openingBalance,
      Value<String?> phone,
      Value<String?> address,
      Value<String?> email,
      Value<String?> taxNumber,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$LedgersTableFilterComposer
    extends Composer<_$AppDatabase, $LedgersTable> {
  $$LedgersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgersTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgersTable> {
  $$LedgersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgersTable> {
  $$LedgersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<double> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get taxNumber =>
      $composableBuilder(column: $table.taxNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$LedgersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgersTable,
          Ledger,
          $$LedgersTableFilterComposer,
          $$LedgersTableOrderingComposer,
          $$LedgersTableAnnotationComposer,
          $$LedgersTableCreateCompanionBuilder,
          $$LedgersTableUpdateCompanionBuilder,
          (Ledger, BaseReferences<_$AppDatabase, $LedgersTable, Ledger>),
          Ledger,
          PrefetchHooks Function()
        > {
  $$LedgersTableTableManager(_$AppDatabase db, $LedgersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<double> openingBalance = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgersCompanion(
                id: id,
                name: name,
                groupId: groupId,
                openingBalance: openingBalance,
                phone: phone,
                address: address,
                email: email,
                taxNumber: taxNumber,
                updatedAt: updatedAt,
                isSynced: isSynced,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String groupId,
                Value<double> openingBalance = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgersCompanion.insert(
                id: id,
                name: name,
                groupId: groupId,
                openingBalance: openingBalance,
                phone: phone,
                address: address,
                email: email,
                taxNumber: taxNumber,
                updatedAt: updatedAt,
                isSynced: isSynced,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgersTable,
      Ledger,
      $$LedgersTableFilterComposer,
      $$LedgersTableOrderingComposer,
      $$LedgersTableAnnotationComposer,
      $$LedgersTableCreateCompanionBuilder,
      $$LedgersTableUpdateCompanionBuilder,
      (Ledger, BaseReferences<_$AppDatabase, $LedgersTable, Ledger>),
      Ledger,
      PrefetchHooks Function()
    >;
typedef $$StockItemsTableCreateCompanionBuilder =
    StockItemsCompanion Function({
      required String id,
      required String name,
      Value<String?> sku,
      Value<String> unitOfMeasure,
      Value<double> openingQuantity,
      Value<double> openingRate,
      Value<double> purchaseRate,
      Value<double> salesRate,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<int> rowid,
    });
typedef $$StockItemsTableUpdateCompanionBuilder =
    StockItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> sku,
      Value<String> unitOfMeasure,
      Value<double> openingQuantity,
      Value<double> openingRate,
      Value<double> purchaseRate,
      Value<double> salesRate,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<int> rowid,
    });

class $$StockItemsTableFilterComposer
    extends Composer<_$AppDatabase, $StockItemsTable> {
  $$StockItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitOfMeasure => $composableBuilder(
    column: $table.unitOfMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get openingQuantity => $composableBuilder(
    column: $table.openingQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get openingRate => $composableBuilder(
    column: $table.openingRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get purchaseRate => $composableBuilder(
    column: $table.purchaseRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get salesRate => $composableBuilder(
    column: $table.salesRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockItemsTable> {
  $$StockItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitOfMeasure => $composableBuilder(
    column: $table.unitOfMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get openingQuantity => $composableBuilder(
    column: $table.openingQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get openingRate => $composableBuilder(
    column: $table.openingRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get purchaseRate => $composableBuilder(
    column: $table.purchaseRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get salesRate => $composableBuilder(
    column: $table.salesRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockItemsTable> {
  $$StockItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get unitOfMeasure => $composableBuilder(
    column: $table.unitOfMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<double> get openingQuantity => $composableBuilder(
    column: $table.openingQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<double> get openingRate => $composableBuilder(
    column: $table.openingRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get purchaseRate => $composableBuilder(
    column: $table.purchaseRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get salesRate =>
      $composableBuilder(column: $table.salesRate, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$StockItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockItemsTable,
          StockItem,
          $$StockItemsTableFilterComposer,
          $$StockItemsTableOrderingComposer,
          $$StockItemsTableAnnotationComposer,
          $$StockItemsTableCreateCompanionBuilder,
          $$StockItemsTableUpdateCompanionBuilder,
          (
            StockItem,
            BaseReferences<_$AppDatabase, $StockItemsTable, StockItem>,
          ),
          StockItem,
          PrefetchHooks Function()
        > {
  $$StockItemsTableTableManager(_$AppDatabase db, $StockItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String> unitOfMeasure = const Value.absent(),
                Value<double> openingQuantity = const Value.absent(),
                Value<double> openingRate = const Value.absent(),
                Value<double> purchaseRate = const Value.absent(),
                Value<double> salesRate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockItemsCompanion(
                id: id,
                name: name,
                sku: sku,
                unitOfMeasure: unitOfMeasure,
                openingQuantity: openingQuantity,
                openingRate: openingRate,
                purchaseRate: purchaseRate,
                salesRate: salesRate,
                updatedAt: updatedAt,
                isSynced: isSynced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> sku = const Value.absent(),
                Value<String> unitOfMeasure = const Value.absent(),
                Value<double> openingQuantity = const Value.absent(),
                Value<double> openingRate = const Value.absent(),
                Value<double> purchaseRate = const Value.absent(),
                Value<double> salesRate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockItemsCompanion.insert(
                id: id,
                name: name,
                sku: sku,
                unitOfMeasure: unitOfMeasure,
                openingQuantity: openingQuantity,
                openingRate: openingRate,
                purchaseRate: purchaseRate,
                salesRate: salesRate,
                updatedAt: updatedAt,
                isSynced: isSynced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockItemsTable,
      StockItem,
      $$StockItemsTableFilterComposer,
      $$StockItemsTableOrderingComposer,
      $$StockItemsTableAnnotationComposer,
      $$StockItemsTableCreateCompanionBuilder,
      $$StockItemsTableUpdateCompanionBuilder,
      (StockItem, BaseReferences<_$AppDatabase, $StockItemsTable, StockItem>),
      StockItem,
      PrefetchHooks Function()
    >;
typedef $$VouchersTableCreateCompanionBuilder =
    VouchersCompanion Function({
      required String id,
      required String voucherNumber,
      required String voucherType,
      Value<String> financialYear,
      required DateTime date,
      Value<String?> narration,
      Value<String?> referenceNumber,
      Value<String> status,
      Value<double> discountAmount,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<int> rowid,
    });
typedef $$VouchersTableUpdateCompanionBuilder =
    VouchersCompanion Function({
      Value<String> id,
      Value<String> voucherNumber,
      Value<String> voucherType,
      Value<String> financialYear,
      Value<DateTime> date,
      Value<String?> narration,
      Value<String?> referenceNumber,
      Value<String> status,
      Value<double> discountAmount,
      Value<DateTime> updatedAt,
      Value<bool> isSynced,
      Value<int> rowid,
    });

class $$VouchersTableFilterComposer
    extends Composer<_$AppDatabase, $VouchersTable> {
  $$VouchersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voucherNumber => $composableBuilder(
    column: $table.voucherNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voucherType => $composableBuilder(
    column: $table.voucherType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get financialYear => $composableBuilder(
    column: $table.financialYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narration => $composableBuilder(
    column: $table.narration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VouchersTableOrderingComposer
    extends Composer<_$AppDatabase, $VouchersTable> {
  $$VouchersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voucherNumber => $composableBuilder(
    column: $table.voucherNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voucherType => $composableBuilder(
    column: $table.voucherType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get financialYear => $composableBuilder(
    column: $table.financialYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narration => $composableBuilder(
    column: $table.narration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VouchersTableAnnotationComposer
    extends Composer<_$AppDatabase, $VouchersTable> {
  $$VouchersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get voucherNumber => $composableBuilder(
    column: $table.voucherNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voucherType => $composableBuilder(
    column: $table.voucherType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get financialYear => $composableBuilder(
    column: $table.financialYear,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get narration =>
      $composableBuilder(column: $table.narration, builder: (column) => column);

  GeneratedColumn<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$VouchersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VouchersTable,
          Voucher,
          $$VouchersTableFilterComposer,
          $$VouchersTableOrderingComposer,
          $$VouchersTableAnnotationComposer,
          $$VouchersTableCreateCompanionBuilder,
          $$VouchersTableUpdateCompanionBuilder,
          (Voucher, BaseReferences<_$AppDatabase, $VouchersTable, Voucher>),
          Voucher,
          PrefetchHooks Function()
        > {
  $$VouchersTableTableManager(_$AppDatabase db, $VouchersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VouchersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VouchersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VouchersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> voucherNumber = const Value.absent(),
                Value<String> voucherType = const Value.absent(),
                Value<String> financialYear = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> narration = const Value.absent(),
                Value<String?> referenceNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> discountAmount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VouchersCompanion(
                id: id,
                voucherNumber: voucherNumber,
                voucherType: voucherType,
                financialYear: financialYear,
                date: date,
                narration: narration,
                referenceNumber: referenceNumber,
                status: status,
                discountAmount: discountAmount,
                updatedAt: updatedAt,
                isSynced: isSynced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String voucherNumber,
                required String voucherType,
                Value<String> financialYear = const Value.absent(),
                required DateTime date,
                Value<String?> narration = const Value.absent(),
                Value<String?> referenceNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> discountAmount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VouchersCompanion.insert(
                id: id,
                voucherNumber: voucherNumber,
                voucherType: voucherType,
                financialYear: financialYear,
                date: date,
                narration: narration,
                referenceNumber: referenceNumber,
                status: status,
                discountAmount: discountAmount,
                updatedAt: updatedAt,
                isSynced: isSynced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VouchersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VouchersTable,
      Voucher,
      $$VouchersTableFilterComposer,
      $$VouchersTableOrderingComposer,
      $$VouchersTableAnnotationComposer,
      $$VouchersTableCreateCompanionBuilder,
      $$VouchersTableUpdateCompanionBuilder,
      (Voucher, BaseReferences<_$AppDatabase, $VouchersTable, Voucher>),
      Voucher,
      PrefetchHooks Function()
    >;
typedef $$VoucherEntriesTableCreateCompanionBuilder =
    VoucherEntriesCompanion Function({
      required String id,
      required String voucherId,
      required String ledgerId,
      Value<double> debitAmount,
      Value<double> creditAmount,
      Value<int> rowid,
    });
typedef $$VoucherEntriesTableUpdateCompanionBuilder =
    VoucherEntriesCompanion Function({
      Value<String> id,
      Value<String> voucherId,
      Value<String> ledgerId,
      Value<double> debitAmount,
      Value<double> creditAmount,
      Value<int> rowid,
    });

class $$VoucherEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $VoucherEntriesTable> {
  $$VoucherEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voucherId => $composableBuilder(
    column: $table.voucherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get debitAmount => $composableBuilder(
    column: $table.debitAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get creditAmount => $composableBuilder(
    column: $table.creditAmount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VoucherEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VoucherEntriesTable> {
  $$VoucherEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voucherId => $composableBuilder(
    column: $table.voucherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get debitAmount => $composableBuilder(
    column: $table.debitAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get creditAmount => $composableBuilder(
    column: $table.creditAmount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VoucherEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoucherEntriesTable> {
  $$VoucherEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get voucherId =>
      $composableBuilder(column: $table.voucherId, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<double> get debitAmount => $composableBuilder(
    column: $table.debitAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get creditAmount => $composableBuilder(
    column: $table.creditAmount,
    builder: (column) => column,
  );
}

class $$VoucherEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoucherEntriesTable,
          VoucherEntry,
          $$VoucherEntriesTableFilterComposer,
          $$VoucherEntriesTableOrderingComposer,
          $$VoucherEntriesTableAnnotationComposer,
          $$VoucherEntriesTableCreateCompanionBuilder,
          $$VoucherEntriesTableUpdateCompanionBuilder,
          (
            VoucherEntry,
            BaseReferences<_$AppDatabase, $VoucherEntriesTable, VoucherEntry>,
          ),
          VoucherEntry,
          PrefetchHooks Function()
        > {
  $$VoucherEntriesTableTableManager(
    _$AppDatabase db,
    $VoucherEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoucherEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoucherEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoucherEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> voucherId = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<double> debitAmount = const Value.absent(),
                Value<double> creditAmount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoucherEntriesCompanion(
                id: id,
                voucherId: voucherId,
                ledgerId: ledgerId,
                debitAmount: debitAmount,
                creditAmount: creditAmount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String voucherId,
                required String ledgerId,
                Value<double> debitAmount = const Value.absent(),
                Value<double> creditAmount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoucherEntriesCompanion.insert(
                id: id,
                voucherId: voucherId,
                ledgerId: ledgerId,
                debitAmount: debitAmount,
                creditAmount: creditAmount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VoucherEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoucherEntriesTable,
      VoucherEntry,
      $$VoucherEntriesTableFilterComposer,
      $$VoucherEntriesTableOrderingComposer,
      $$VoucherEntriesTableAnnotationComposer,
      $$VoucherEntriesTableCreateCompanionBuilder,
      $$VoucherEntriesTableUpdateCompanionBuilder,
      (
        VoucherEntry,
        BaseReferences<_$AppDatabase, $VoucherEntriesTable, VoucherEntry>,
      ),
      VoucherEntry,
      PrefetchHooks Function()
    >;
typedef $$StockTransactionsTableCreateCompanionBuilder =
    StockTransactionsCompanion Function({
      required String id,
      required String voucherId,
      required String stockItemId,
      required double quantity,
      required double rate,
      required String transactionType,
      Value<bool> isReplacement,
      Value<int> rowid,
    });
typedef $$StockTransactionsTableUpdateCompanionBuilder =
    StockTransactionsCompanion Function({
      Value<String> id,
      Value<String> voucherId,
      Value<String> stockItemId,
      Value<double> quantity,
      Value<double> rate,
      Value<String> transactionType,
      Value<bool> isReplacement,
      Value<int> rowid,
    });

class $$StockTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voucherId => $composableBuilder(
    column: $table.voucherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stockItemId => $composableBuilder(
    column: $table.stockItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReplacement => $composableBuilder(
    column: $table.isReplacement,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voucherId => $composableBuilder(
    column: $table.voucherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stockItemId => $composableBuilder(
    column: $table.stockItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReplacement => $composableBuilder(
    column: $table.isReplacement,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockTransactionsTable> {
  $$StockTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get voucherId =>
      $composableBuilder(column: $table.voucherId, builder: (column) => column);

  GeneratedColumn<String> get stockItemId => $composableBuilder(
    column: $table.stockItemId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isReplacement => $composableBuilder(
    column: $table.isReplacement,
    builder: (column) => column,
  );
}

class $$StockTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockTransactionsTable,
          StockTransaction,
          $$StockTransactionsTableFilterComposer,
          $$StockTransactionsTableOrderingComposer,
          $$StockTransactionsTableAnnotationComposer,
          $$StockTransactionsTableCreateCompanionBuilder,
          $$StockTransactionsTableUpdateCompanionBuilder,
          (
            StockTransaction,
            BaseReferences<
              _$AppDatabase,
              $StockTransactionsTable,
              StockTransaction
            >,
          ),
          StockTransaction,
          PrefetchHooks Function()
        > {
  $$StockTransactionsTableTableManager(
    _$AppDatabase db,
    $StockTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> voucherId = const Value.absent(),
                Value<String> stockItemId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<String> transactionType = const Value.absent(),
                Value<bool> isReplacement = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockTransactionsCompanion(
                id: id,
                voucherId: voucherId,
                stockItemId: stockItemId,
                quantity: quantity,
                rate: rate,
                transactionType: transactionType,
                isReplacement: isReplacement,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String voucherId,
                required String stockItemId,
                required double quantity,
                required double rate,
                required String transactionType,
                Value<bool> isReplacement = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockTransactionsCompanion.insert(
                id: id,
                voucherId: voucherId,
                stockItemId: stockItemId,
                quantity: quantity,
                rate: rate,
                transactionType: transactionType,
                isReplacement: isReplacement,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockTransactionsTable,
      StockTransaction,
      $$StockTransactionsTableFilterComposer,
      $$StockTransactionsTableOrderingComposer,
      $$StockTransactionsTableAnnotationComposer,
      $$StockTransactionsTableCreateCompanionBuilder,
      $$StockTransactionsTableUpdateCompanionBuilder,
      (
        StockTransaction,
        BaseReferences<
          _$AppDatabase,
          $StockTransactionsTable,
          StockTransaction
        >,
      ),
      StockTransaction,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;
typedef $$InvoiceSequencesTableCreateCompanionBuilder =
    InvoiceSequencesCompanion Function({
      required String id,
      required String financialYear,
      required String voucherType,
      Value<int> nextNumber,
      Value<int> rowid,
    });
typedef $$InvoiceSequencesTableUpdateCompanionBuilder =
    InvoiceSequencesCompanion Function({
      Value<String> id,
      Value<String> financialYear,
      Value<String> voucherType,
      Value<int> nextNumber,
      Value<int> rowid,
    });

class $$InvoiceSequencesTableFilterComposer
    extends Composer<_$AppDatabase, $InvoiceSequencesTable> {
  $$InvoiceSequencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get financialYear => $composableBuilder(
    column: $table.financialYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voucherType => $composableBuilder(
    column: $table.voucherType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextNumber => $composableBuilder(
    column: $table.nextNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvoiceSequencesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoiceSequencesTable> {
  $$InvoiceSequencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get financialYear => $composableBuilder(
    column: $table.financialYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voucherType => $composableBuilder(
    column: $table.voucherType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextNumber => $composableBuilder(
    column: $table.nextNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvoiceSequencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoiceSequencesTable> {
  $$InvoiceSequencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get financialYear => $composableBuilder(
    column: $table.financialYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voucherType => $composableBuilder(
    column: $table.voucherType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextNumber => $composableBuilder(
    column: $table.nextNumber,
    builder: (column) => column,
  );
}

class $$InvoiceSequencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvoiceSequencesTable,
          InvoiceSequence,
          $$InvoiceSequencesTableFilterComposer,
          $$InvoiceSequencesTableOrderingComposer,
          $$InvoiceSequencesTableAnnotationComposer,
          $$InvoiceSequencesTableCreateCompanionBuilder,
          $$InvoiceSequencesTableUpdateCompanionBuilder,
          (
            InvoiceSequence,
            BaseReferences<
              _$AppDatabase,
              $InvoiceSequencesTable,
              InvoiceSequence
            >,
          ),
          InvoiceSequence,
          PrefetchHooks Function()
        > {
  $$InvoiceSequencesTableTableManager(
    _$AppDatabase db,
    $InvoiceSequencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoiceSequencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoiceSequencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoiceSequencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> financialYear = const Value.absent(),
                Value<String> voucherType = const Value.absent(),
                Value<int> nextNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoiceSequencesCompanion(
                id: id,
                financialYear: financialYear,
                voucherType: voucherType,
                nextNumber: nextNumber,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String financialYear,
                required String voucherType,
                Value<int> nextNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoiceSequencesCompanion.insert(
                id: id,
                financialYear: financialYear,
                voucherType: voucherType,
                nextNumber: nextNumber,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvoiceSequencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvoiceSequencesTable,
      InvoiceSequence,
      $$InvoiceSequencesTableFilterComposer,
      $$InvoiceSequencesTableOrderingComposer,
      $$InvoiceSequencesTableAnnotationComposer,
      $$InvoiceSequencesTableCreateCompanionBuilder,
      $$InvoiceSequencesTableUpdateCompanionBuilder,
      (
        InvoiceSequence,
        BaseReferences<_$AppDatabase, $InvoiceSequencesTable, InvoiceSequence>,
      ),
      InvoiceSequence,
      PrefetchHooks Function()
    >;
typedef $$AuditLogsTableCreateCompanionBuilder =
    AuditLogsCompanion Function({
      required String id,
      Value<DateTime> timestamp,
      Value<String> userDevice,
      required String action,
      required String entityType,
      required String entityId,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<String?> metadata,
      Value<int> rowid,
    });
typedef $$AuditLogsTableUpdateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<String> id,
      Value<DateTime> timestamp,
      Value<String> userDevice,
      Value<String> action,
      Value<String> entityType,
      Value<String> entityId,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<String?> metadata,
      Value<int> rowid,
    });

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userDevice => $composableBuilder(
    column: $table.userDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userDevice => $composableBuilder(
    column: $table.userDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get userDevice => $composableBuilder(
    column: $table.userDevice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get oldValue =>
      $composableBuilder(column: $table.oldValue, builder: (column) => column);

  GeneratedColumn<String> get newValue =>
      $composableBuilder(column: $table.newValue, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLog,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
          AuditLog,
          PrefetchHooks Function()
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> userDevice = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                timestamp: timestamp,
                userDevice: userDevice,
                action: action,
                entityType: entityType,
                entityId: entityId,
                oldValue: oldValue,
                newValue: newValue,
                metadata: metadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> userDevice = const Value.absent(),
                required String action,
                required String entityType,
                required String entityId,
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion.insert(
                id: id,
                timestamp: timestamp,
                userDevice: userDevice,
                action: action,
                entityType: entityType,
                entityId: entityId,
                oldValue: oldValue,
                newValue: newValue,
                metadata: metadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLog,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
      AuditLog,
      PrefetchHooks Function()
    >;
typedef $$BusinessProfilesTableCreateCompanionBuilder =
    BusinessProfilesCompanion Function({
      required String id,
      required String companyName,
      Value<String?> address,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> taxNumber,
      Value<String?> bankDetails,
      Value<String?> termsAndConditions,
      Value<String?> logoPath,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BusinessProfilesTableUpdateCompanionBuilder =
    BusinessProfilesCompanion Function({
      Value<String> id,
      Value<String> companyName,
      Value<String?> address,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> taxNumber,
      Value<String?> bankDetails,
      Value<String?> termsAndConditions,
      Value<String?> logoPath,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BusinessProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $BusinessProfilesTable> {
  $$BusinessProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankDetails => $composableBuilder(
    column: $table.bankDetails,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get termsAndConditions => $composableBuilder(
    column: $table.termsAndConditions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BusinessProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $BusinessProfilesTable> {
  $$BusinessProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankDetails => $composableBuilder(
    column: $table.bankDetails,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get termsAndConditions => $composableBuilder(
    column: $table.termsAndConditions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BusinessProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BusinessProfilesTable> {
  $$BusinessProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get taxNumber =>
      $composableBuilder(column: $table.taxNumber, builder: (column) => column);

  GeneratedColumn<String> get bankDetails => $composableBuilder(
    column: $table.bankDetails,
    builder: (column) => column,
  );

  GeneratedColumn<String> get termsAndConditions => $composableBuilder(
    column: $table.termsAndConditions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logoPath =>
      $composableBuilder(column: $table.logoPath, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BusinessProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BusinessProfilesTable,
          BusinessProfile,
          $$BusinessProfilesTableFilterComposer,
          $$BusinessProfilesTableOrderingComposer,
          $$BusinessProfilesTableAnnotationComposer,
          $$BusinessProfilesTableCreateCompanionBuilder,
          $$BusinessProfilesTableUpdateCompanionBuilder,
          (
            BusinessProfile,
            BaseReferences<
              _$AppDatabase,
              $BusinessProfilesTable,
              BusinessProfile
            >,
          ),
          BusinessProfile,
          PrefetchHooks Function()
        > {
  $$BusinessProfilesTableTableManager(
    _$AppDatabase db,
    $BusinessProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyName = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<String?> bankDetails = const Value.absent(),
                Value<String?> termsAndConditions = const Value.absent(),
                Value<String?> logoPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BusinessProfilesCompanion(
                id: id,
                companyName: companyName,
                address: address,
                phone: phone,
                email: email,
                taxNumber: taxNumber,
                bankDetails: bankDetails,
                termsAndConditions: termsAndConditions,
                logoPath: logoPath,
                isActive: isActive,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyName,
                Value<String?> address = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<String?> bankDetails = const Value.absent(),
                Value<String?> termsAndConditions = const Value.absent(),
                Value<String?> logoPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BusinessProfilesCompanion.insert(
                id: id,
                companyName: companyName,
                address: address,
                phone: phone,
                email: email,
                taxNumber: taxNumber,
                bankDetails: bankDetails,
                termsAndConditions: termsAndConditions,
                logoPath: logoPath,
                isActive: isActive,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BusinessProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BusinessProfilesTable,
      BusinessProfile,
      $$BusinessProfilesTableFilterComposer,
      $$BusinessProfilesTableOrderingComposer,
      $$BusinessProfilesTableAnnotationComposer,
      $$BusinessProfilesTableCreateCompanionBuilder,
      $$BusinessProfilesTableUpdateCompanionBuilder,
      (
        BusinessProfile,
        BaseReferences<_$AppDatabase, $BusinessProfilesTable, BusinessProfile>,
      ),
      BusinessProfile,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountGroupsTableTableManager get accountGroups =>
      $$AccountGroupsTableTableManager(_db, _db.accountGroups);
  $$LedgersTableTableManager get ledgers =>
      $$LedgersTableTableManager(_db, _db.ledgers);
  $$StockItemsTableTableManager get stockItems =>
      $$StockItemsTableTableManager(_db, _db.stockItems);
  $$VouchersTableTableManager get vouchers =>
      $$VouchersTableTableManager(_db, _db.vouchers);
  $$VoucherEntriesTableTableManager get voucherEntries =>
      $$VoucherEntriesTableTableManager(_db, _db.voucherEntries);
  $$StockTransactionsTableTableManager get stockTransactions =>
      $$StockTransactionsTableTableManager(_db, _db.stockTransactions);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
  $$InvoiceSequencesTableTableManager get invoiceSequences =>
      $$InvoiceSequencesTableTableManager(_db, _db.invoiceSequences);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$BusinessProfilesTableTableManager get businessProfiles =>
      $$BusinessProfilesTableTableManager(_db, _db.businessProfiles);
}
