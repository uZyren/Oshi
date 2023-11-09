// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionsDataAdapter extends TypeAdapter<SessionsData> {
  @override
  final int typeId = 2;

  @override
  SessionsData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionsData(
      sessions: (fields[2] as Map?)?.cast<String, Session>(),
      lastSessionId: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionsData obj) {
    writer
      ..writeByte(2)
      ..writeByte(1)
      ..write(obj.lastSessionId)
      ..writeByte(2)
      ..write(obj.sessions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionsDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionAdapter extends TypeAdapter<Session> {
  @override
  final int typeId = 3;

  @override
  Session read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Session(
      sessionName: fields[1] as String,
      providerGuid: fields[5] as String,
      changes: (fields[3] as List?)?.cast<RegisterChanges>(),
    )
      ..sessionCredentials = (fields[2] as Map).cast<String, String>()
      ..data = fields[4] as ProviderData;
  }

  @override
  void write(BinaryWriter writer, Session obj) {
    writer
      ..writeByte(5)
      ..writeByte(1)
      ..write(obj.sessionName)
      ..writeByte(2)
      ..write(obj.sessionCredentials)
      ..writeByte(3)
      ..write(obj.changes)
      ..writeByte(4)
      ..write(obj.data)
      ..writeByte(5)
      ..write(obj.providerGuid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RegisterChangesAdapter extends TypeAdapter<RegisterChanges> {
  @override
  final int typeId = 59;

  @override
  RegisterChanges read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegisterChanges(
      refreshDate: fields[0] as DateTime?,
    )
      ..timetablesChanged =
          (fields[1] as List).cast<RegisterChange<TimetableLesson>>()
      ..gradesChanged = (fields[2] as List).cast<RegisterChange<Grade>>()
      ..eventsChanged = (fields[3] as List).cast<RegisterChange<Event>>()
      ..announcementsChanged =
          (fields[4] as List).cast<RegisterChange<Announcement>>()
      ..messagesChanged = (fields[5] as List).cast<RegisterChange<Message>>()
      ..attendancesChanged =
          (fields[6] as List).cast<RegisterChange<Attendance>>();
  }

  @override
  void write(BinaryWriter writer, RegisterChanges obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.refreshDate)
      ..writeByte(1)
      ..write(obj.timetablesChanged)
      ..writeByte(2)
      ..write(obj.gradesChanged)
      ..writeByte(3)
      ..write(obj.eventsChanged)
      ..writeByte(4)
      ..write(obj.announcementsChanged)
      ..writeByte(5)
      ..write(obj.messagesChanged)
      ..writeByte(6)
      ..write(obj.attendancesChanged);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterChangesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
