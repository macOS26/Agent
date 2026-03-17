<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE dictionary SYSTEM "file://localhost/System/Library/DTDs/sdef.dtd">
<dictionary xmlns:xi="http://www.w3.org/2001/XInclude">
    <xi:include href="file:///System/Library/ScriptingDefinitions/CocoaStandard.sdef" xpointer="xpointer(/dictionary/suite)" />

    <suite name="Reminders Suite" code="remi" description="Terms and Events for controlling the Reminders application">
        <command name="show" code="remishow" description="Show an object in the Reminders UI">
            <access-group identifier="com.apple.Reminders.UI" />
            <direct-parameter description="The object to be shown">
                <type type="list" />
                <type type="reminder" />
            </direct-parameter>
            <result description="The object shown">
                <type type="list" />
                <type type="reminder" />
            </result>
        </command>

        <class-extension extends="application" description="The Reminders application">
            <access-group identifier="com.apple.reminders.read-write" access="rw" />
            <access-group identifier="com.apple.reminders.read" access="r" />
            <cocoa class="TTRMApplication" />
            <element type="account" access="r">
                <cocoa key="scriptingAccounts" />
            </element>
            <property name="default account" code="dact" type="account" access="r" description="The default account in the Reminders application">
                <cocoa key="scriptingDefaultAccount" />
            </property>
            <element type="list">
                <cocoa key="scriptingLists" />
            </element>
            <property name="default list" code="dlis" type="list" access="r" description="The default list in the Reminders application">
                <cocoa key="scriptingDefaultList" />
            </property>
            <element type="reminder">
                <cocoa key="scriptingReminders" />
            </element>
        </class-extension>

        <class name="account" code="acct" description="An account in the Reminders application">
            <access-group identifier="com.apple.reminders.read-write" access="rw" />
            <access-group identifier="com.apple.reminders.read" access="r" />
            <cocoa class="TTRMScriptableAccount" />
            <property name="id" code="ID  " type="text" access="r" description="The unique identifier of the account">
                <cocoa key="identifier" />
            </property>
            <property name="name" code="pnam" type="text" access="r" description="The name of the account">
                <cocoa key="name" />
            </property>
            <element type="list">
                <cocoa key="lists" />
            </element>
            <element type="reminder">
                <cocoa key="reminders" />
            </element>
            <responds-to command="show">
                <cocoa method="show:" />
            </responds-to>
        </class>

        <class name="list" plural="lists" code="list" inherits="item" description="A list in the Reminders application">
            <access-group identifier="com.apple.reminders.List.read-write" access="rw" />
            <access-group identifier="com.apple.reminders.read" access="r" />
            <cocoa class="TTRMScriptableList" />
            <property name="id" code="ID  " type="text" access="r" description="The unique identifier of the list">
                <cocoa key="identifier" />
            </property>
            <property name="name" code="pnam" type="text" description="The name of the list">
                <cocoa key="name" />
            </property>
            <property name="container" code="cntr" access="r" description="The container of the list">
                <type type="account" />
                <type type="list" />
                <cocoa key="container" />
            </property>
            <property name="color" code="colr" type="text" description="The color of the list">
                <cocoa key="color" />
            </property>
            <property name="emblem" code="iimg" type="text" description="The emblem icon name of the list">
                <cocoa key="emblem" />
            </property>
            <element type="reminder">
                <cocoa key="reminders" />
            </element>
            <responds-to command="show">
                <cocoa method="show:" />
            </responds-to>
        </class>

        <class name="reminder" plural="reminders" code="remi" inherits="item" description="A reminder in the Reminders application">
            <access-group identifier="com.apple.Reminders.read-write" access="rw" />
            <access-group identifier="com.apple.Reminders.read" access="r" />
            <cocoa class="TTRMScriptableReminder" />
            <property name="name" code="pnam" type="text" description="The name of the reminder">
                <cocoa key="name" />
            </property>
            <property name="id" code="ID  " type="text" access="r" description="The unique identifier of the reminder">
                <cocoa key="identifier" />
            </property>
            <property name="container" code="cntr" access="r" description="The container of the reminder">
                <type type="list" />
                <type type="reminder" />
                <cocoa key="container" />
            </property>
            <property name="creation date" code="ascd" type="date" access="r" description="The creation date of the reminder">
                <cocoa key="createdAt" />
            </property>
            <property name="modification date" code="asmo" type="date" access="r" description="The modification date of the reminder">
                <cocoa key="modifiedAt" />
            </property>
            <property name="body" code="body" type="text" description="The notes attached to the reminder">
                <cocoa key="notes" />
            </property>
            <property name="completed" code="comb" type="boolean" description="Whether the reminder is completed">
                <cocoa key="isCompleted" />
            </property>
            <property name="completion date" code="comd" type="date" description="The completion date of the reminder">
                <cocoa key="completedAt" />
            </property>
            <property name="due date" code="dued" type="date" description="The due date of the reminder; will set both date and time">
                <cocoa key="dueAt" />
            </property>
            <property name="allday due date" code="adue" type="date" description="The all-day due date of the reminder; will only set a date">
                <cocoa key="allDayDueAt" />
            </property>
            <property name="remind me date" code="rmdt" type="date" description="The remind date of the reminder">
                <cocoa key="remindMeAt" />
            </property>
            <property name="priority" code="prio" type="integer" description="The priority of the reminder; 0: no priority, 1–4: high, 5: medium, 6–9: low">
                <cocoa key="priority" />
            </property>
            <property name="flagged" code="flgd" type="boolean" description="Whether the reminder is flagged">
                <cocoa key="isFlagged" />
            </property>
            <responds-to command="show">
                <cocoa method="show:" />
            </responds-to>
        </class>

        <!-- this is required by Cocoa Scripting -->
        <enumeration name="saveable file format" code="savf">
            <enumerator name="text" code="ctxt" description="Text File Format">
                <cocoa string-value="public.text" />
            </enumerator>
        </enumeration>
    </suite>
</dictionary>
