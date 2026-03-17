<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE dictionary SYSTEM "file://localhost/System/Library/DTDs/sdef.dtd">
<dictionary xmlns:xi="http://www.w3.org/2003/XInclude">

	<suite name="Standard Suite" code="????" description="Common classes and commands for all applications.">

		<xi:include href="file:///System/Library/ScriptingDefinitions/CocoaStandard.sdef" xpointer="xpointer(/dictionary/suite/node()[not(self::command and @name = 'save')])"/> 

	</suite>
		
	<suite name="iCal" code="wrbt" description="iCal classes and commands">

		<value-type name="RGB color" code="cRGB">
			<cocoa class="NSColor"/>
		</value-type>

		<enumeration name="participation status" code="wre6">
            <synonym name ="CALParticipationStatus"/>
			<enumerator name="unknown" code="E6na" description="No anwser yet"/>
			<enumerator name="accepted" code="E6ap" description="Invitation has been accepted"/>
			<enumerator name="declined" code="E6dp" description="Invitation has been declined"/>
			<enumerator name="tentative" code="E6tp" description="Invitation has been tentatively accepted"/>
		</enumeration>

		<enumeration name="event status" code="wre4">
            <synonym name ="CALStatusType"/>
			<enumerator name="cancelled" code="E4ca" description="A cancelled event"/>
			<enumerator name="confirmed" code="E4cn" description="A confirmed event"/>
			<enumerator name="none" code="E4no" description="An event without status"/>
			<enumerator name="tentative" code="E4te" description="A tentative event"/>
		</enumeration>

		<enumeration name="calendar priority" code="wrp1">
            <synonym name ="CALPriorities"/>
			<enumerator name="no priority" code="tdp0" description="No priority"/>
			<enumerator name="low priority" code="tdp9" description="Low priority"/>
			<enumerator name="medium priority" code="tdp5" description="Medium priority"/>
			<enumerator name="high priority" code="tdp1" description="High priority"/>
		</enumeration>

		<enumeration name="view type" code="wre5">
            <synonym name ="CALViewTypeForScripting"/>
			<enumerator name="day view" code="E5da" description="The iCal day view"/>
			<enumerator name="week view" code="E5we" description="The iCal week view"/>
			<enumerator name="month view" code="E5mo" description="The iCal month view"/>
		</enumeration>

		<class-extension extends="application" description="This class represents iCal.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="CALApplication"/>
			<element type="calendar">
				<cocoa key="orderedCalendars"/>
			</element>
			<responds-to command="open">
				<cocoa method="openCommand:"/>
			</responds-to>
			<responds-to command="create calendar">
				<cocoa method="newcalendarCommand:"/>
			</responds-to>
			<responds-to command="view calendar">
				<cocoa method="goToDateCommand:"/>
			</responds-to>
			<responds-to command="switch view">
				<cocoa method="goToViewCommand:"/>
			</responds-to>
			<responds-to command="reload calendars">
				<cocoa method="reloadCalsForScripting:"/>
			</responds-to>
			<responds-to command="save">
				<cocoa method="saveForScripting:"/>
			</responds-to>
		</class-extension>

		<class name="calendar" code="wres" description="This class represents a calendar.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="ScriptableCalendar"/>
			<element type="event">
				<cocoa key="events"/>
			</element>
			<property name="name" code="pnam" type="text" description="This is the calendar title.">
				<cocoa key="title"/>
			</property>
			<property name="title" code="wr02" type="text" hidden="yes" description="This is the calendar title.">
			</property>
			<property name="color" code="colr" type="RGB color" description="The calendar color.">
			</property>
			<property name="calendarIdentifier" code="ID  "  access="r" type="text" description="An unique calendar key">
				<synonym code="wr10"/>
			</property>
			<property name="writable" code="wr05"  access="r" type="boolean" description="This is the calendar title.">
            </property>
			<property name="description" code="wr12" type="text" description="This is the calendar description.">
			</property>
		</class>

		<class name="display alarm" code="wal1" description="This class represents a message alarm.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="ScriptableAlarm"/>
			<property name="trigger interval" code="wald" type="integer" description="The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).">
				<cocoa key="triggerDuration"/>
			</property>
			<property name="trigger date" code="wale" type="date" description="An absolute alarm date.">
				<cocoa key="triggerDate"/>
			</property>
		</class>

		<class name="mail alarm" code="wal2" description="This class represents a mail alarm.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="ScriptableAlarm"/>
			<property name="trigger interval" code="wald" type="integer" description="The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).">
				<cocoa key="triggerDuration"/>
			</property>
			<property name="trigger date" code="wale" type="date" description="An absolute alarm date.">
				<cocoa key="triggerDate"/>
			</property>
		</class>

		<class name="sound alarm" code="wal4" description="This class represents a sound alarm.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="ScriptableAlarm"/>
			<property name="trigger interval" code="wald" type="integer" description="The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).">
				<cocoa key="triggerDuration"/>
			</property>
			<property name="trigger date" code="wale" type="date" description="An absolute alarm date.">
				<cocoa key="triggerDate"/>
			</property>
			<property name="sound name" code="wals" type="text" description="The system sound name to be used for the alarm">
				<cocoa key="soundName"/>
			</property>
			<property name="sound file" code="walf" type="text" description="The (POSIX) path to the sound file to be used for the alarm">
				<cocoa key="soundFile"/>
			</property>
		</class>

		<class name="open file alarm" code="wal3" description="This class represents an 'open file' alarm. Starting with OS X 10.14, it is not possible to create new open file alarms or view URLs for existing open file alarms. Trying to save or modify an open file alarm will result in a save error. Editing other aspects of events or reminders that have existing open file alarms is allowed as long as the alarm isn't modified.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="ScriptableAlarm"/>
			<property name="trigger interval" code="wald" type="integer" description="The interval in minutes between the event and the alarm: (positive for alarm that trigger after the event date or negative for alarms that trigger before).">
				<cocoa key="triggerDuration"/>
			</property>
			<property name="trigger date" code="wale" type="date" description="An absolute alarm date.">
				<cocoa key="triggerDate"/>
			</property>
			<property name="filepath" code="walp" type="text" description="The (POSIX) path to be opened by the alarm">
				<cocoa key="url"/>
			</property>
		</class>

		<class name="attendee" code="wrea" description="This class represents a attendee.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="ScriptableAttendee"/>
			<property name="display name" code="wra1" access="r" type="text" description="The first and last name of the attendee.">
				<cocoa key="displayName"/>
			</property>
			<property name="email" code="wra2" access="r" type="text" description="e-mail of the attendee.">
				<cocoa key="email"/>
			</property>
			<property name="participation status" access="r" code="wra3" type="participation status" description="The invitation status for the attendee.">
				<cocoa key="participationStatus"/>
			</property>
		</class>

		<class name="event" code="wrev" description="This class represents an event.">
            <access-group identifier="com.apple.iCal.read" access="r"/>
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="ScriptableEvent"/>
			<element type="attendee">
				<cocoa key="attendees"/>
			</element>
			<element type="display alarm">
				<cocoa key="messageAlarmsForScripting"/>
			</element>
			<element type="mail alarm">
				<cocoa key="mailAlarmsForScripting"/>
			</element>
			<element type="open file alarm">
				<cocoa key="procAlarmsForScripting"/>
			</element>
			<element type="sound alarm">
				<cocoa key="soundAlarmsForScripting"/>
			</element>
			<property name="description" code="wr12" type="text" description="The events notes.">
				<cocoa key="notes"/>
			</property>
			<property name="start date" code="wr1s" type="date" description="The event start date.">
				<cocoa key="startDate"/>
			</property>
			<property name="end date" code="wr5s" type="date" description="The event end date.">
				<cocoa key="endDate"/>
			</property>
			<property name="allday event" code="wrad" type="boolean" description="True if the event is an all-day event">
				<cocoa key="fullDayEvent"/>
			</property>
			<property name="recurrence" code="wr15" type="text" description="The iCalendar (RFC 2445) string describing the event recurrence, if defined">
				<cocoa key="recurrenceScripting"/>
			</property>
			<property name="sequence" code="wr13" access="r" type="integer" description="The event version.">
            </property>
			<property name="stamp date" code="wr4s" type="date" description="The event modification date.">
				<cocoa key="lastModifiedDate"/>
			</property>
			<property name="excluded dates" code="wr2s" description="The exception dates.">
				<type type="date" list="yes"/>
				<cocoa key="exceptionDates"/>
			</property>
			<property name="status" code="wre4" type="event status" description="The event status.">
            </property>
			<property name="summary" code="wr11" type="text" description="This is the event summary.">
            </property>
			<property name="location" code="wr14" type="text" description="This is the event location.">
            </property>
            <property name="uid" code="ID  " access="r" type="text" description="An unique event key.">
				<synonym code="wr10"/>
			</property>
			<property name="url" code="wr16" access="rw" type="text" description="The URL associated to the event.">
			</property>
			<responds-to command="show">
				<cocoa method="showEntityCommand:"/>
			</responds-to>
		</class>

		<command name="create calendar" code="wrbtaec2" hidden="yes" description="Creates a new calendar (obsolete, will be removed in next release)">
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<parameter name="with name" code="wtnm" optional="yes" type="text" description="the calendar new name">
				<cocoa key="WithName"/>
			</parameter>
		</command>

		<command name="reload calendars" code="wrbtaec8" description="Tell the application to reload all calendar files contents">
            <access-group identifier="com.apple.iCal.UI" access="rw"/>
        </command>

		<command name="switch view" code="wrbtaeca" description="Show calendar on the given view">
            <access-group identifier="com.apple.iCal.UI" access="rw"/>
			<parameter name="to" code="wre5" type="view type" description="the calendar view to be displayed">
				<cocoa key="toView"/>
			</parameter>
		</command>

		<command name="view calendar" code="wrbtaec9" description="Show calendar on the given date">
            <access-group identifier="com.apple.iCal.UI" access="rw"/>
			<parameter name="at" code="wtdt" type="date" description="the date to be displayed">
				<cocoa key="toDate"/>
			</parameter>
		</command>

		<command name="GetURL" code="GURLGURL" description="Subscribe to a remote calendar through a webcal or http URL">
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
			<cocoa class="CALScriptGetURLCommand"/>
			<direct-parameter type="text" description="the iCal URL"/>
		</command>

		<command name="show" code="wrbtaec3" description="Show the event or to-do in the calendar window">
            <access-group identifier="com.apple.iCal.UI" access="rw"/>
			<direct-parameter type="specifier" description="the item"/>
		</command>

		<command name="make" code="corecrel" hidden="yes">
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
            <cocoa class="ScriptableCalendar"/>
			<parameter name="new" code="kocl" type="type" description="The class of the new object.">
				<cocoa key="ObjectClass"/>
			</parameter>
			<parameter name="at" code="insh" type="location specifier" optional="yes" description="The location at which to insert the object.">
				<cocoa key="Location"/>
			</parameter>
			<parameter name="with data" code="data" type="any" optional="yes" description="The initial contents of the object.">
				<cocoa key="ObjectData"/>
			</parameter>
			<parameter name="with properties" code="prdt" type="record" optional="yes" description="The initial values for properties of the object.">
				<cocoa key="KeyDictionary"/>
			</parameter>
			<result type="specifier" description="The new object."/>
		</command>

		<command name="save" code="coresave" hidden="yes">
            <access-group identifier="com.apple.iCal.read-write" access="rw"/>
        </command>

	</suite>
</dictionary>
