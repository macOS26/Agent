<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE dictionary SYSTEM "file://localhost/System/Library/DTDs/sdef.dtd">

<dictionary title="Mail Terminology" xmlns:xi="http://www.w3.org/2003/XInclude">

	<!--
		We would like to import the Cocoa Standard sdef wholesale, but unfortunately we need to override the
		"delete", "duplicate", and "move" command classes with our own custom subclasses in order to have
		decent performance when deleting, copying, and moving large lists of messages, <rdar://problem/3169718>.
	-->
	<suite name="Standard Suite" code="????" description="Common classes and commands for all applications.">
	
		<xi:include href="file://localhost/System/Library/ScriptingDefinitions/CocoaStandard.sdef" xpointer="xpointer(/dictionary/suite/node()[not(self::command and ((@name = 'delete') or (@name = 'duplicate') or (@name = 'move')))])"/>
		
		<command name="delete" code="coredelo" description="Delete an object.">
			<cocoa class="MailDeleteCommand"/>
			<access-group identifier="*"/>
			<direct-parameter type="specifier" description="The object(s) to delete."/>
		</command>

		<command name="duplicate" code="coreclon" description="Copy an object.">
			<cocoa class="MailCopyCommand"/>
			<access-group identifier="*"/>
			<direct-parameter type="specifier" requires-access="r" description="The object(s) to copy."/>
			<parameter name="to" code="insh" type="location specifier" description="The location for the new copy or copies." optional="yes">
				<cocoa key="ToLocation"/>
			</parameter>
			<parameter name="with properties" code="prdt" type="record" description="Properties to set in the new copy or copies right away." optional="yes">
				<cocoa key="WithProperties"/>
			</parameter>
		</command>
	
		<command name="move" code="coremove" description="Move an object to a new location.">
			<cocoa class="MailMoveCommand"/>
			<access-group identifier="*"/>
			<direct-parameter type="specifier" description="The object(s) to move."/>
			<parameter name="to" code="insh" type="location specifier" description="The new location for the object(s).">
				<cocoa key="ToLocation"/>
			</parameter>
		</command>
	
	</suite>
	
	<suite name="Text Suite" code="????" description="A set of basic classes for text processing.">
	
		<access-group identifier="com.apple.mail.compose" access="rw"/>

		<value-type name="RGB color" code="cRGB">
			<cocoa class="NSColor"/>
		</value-type>
		
		<class name="rich text" code="ctxt" plural="rich text" description="Rich (styled) text">
			<cocoa class="NSTextStorage"/>
			<type type="text"/>
			<element type="paragraph"/>
			<element type="word"/>
			<element type="character"/>
			<element type="attribute run"/>
			<element type="attachment"/>
			<property name="color" code="colr" type="RGB color" description="The color of the first character.">
				<cocoa key="foregroundColor"/>
			</property>
			<property name="font" code="font" type="text" description="The name of the font of the first character.">
				<cocoa key="fontName"/>
			</property>
			<property name="size" code="ptsz" type="number" description="The size in points of the first character.">
				<cocoa key="fontSize"/>
			</property>
		</class>
		
		<class name="attachment" code="atts" inherits="rich text" description="Represents an inline text attachment. This class is used mainly for make commands.">
			<cocoa class="NSAttachmentTextStorage"/>
			<property name="file name" code="atfn" type="file" description="The file for the attachment">
				<cocoa key="url"/>
			</property>
		</class>
		
		<class name="paragraph" code="cpar" description="This subdivides the text into paragraphs.">
			<cocoa class="NSTextStorage"/>
			<type type="text"/>
			<element type="word"/>
			<element type="character"/>
			<element type="attribute run"/>
			<element type="attachment"/>
			<property name="color" code="colr" type="RGB color" description="The color of the first character.">
				<cocoa key="foregroundColor"/>
			</property>
			<property name="font" code="font" type="text" description="The name of the font of the first character.">
				<cocoa key="fontName"/>
			</property>
			<property name="size" code="ptsz" type="number" description="The size in points of the first character.">
				<cocoa key="fontSize"/>
			</property>
		</class>
		
		<class name="word" code="cwor" description="This subdivides the text into words.">
			<cocoa class="NSTextStorage"/>
			<type type="text"/>
			<element type="character"/>
			<element type="attribute run"/>
			<element type="attachment"/>
			<property name="color" code="colr" type="RGB color" description="The color of the first character.">
				<cocoa key="foregroundColor"/>
			</property>
			<property name="font" code="font" type="text" description="The name of the font of the first character.">
				<cocoa key="fontName"/>
			</property>
			<property name="size" code="ptsz" type="number" description="The size in points of the first character.">
				<cocoa key="fontSize"/>
			</property>
		</class>
		
		<class name="character" code="cha " description="This subdivides the text into characters.">
			<cocoa class="NSTextStorage"/>
			<type type="text"/>
			<element type="attribute run"/>
			<element type="attachment"/>
			<property name="color" code="colr" type="RGB color" description="The color of the character.">
				<cocoa key="foregroundColor"/>
			</property>
			<property name="font" code="font" type="text" description="The name of the font of the character.">
				<cocoa key="fontName"/>
			</property>
			<property name="size" code="ptsz" type="number" description="The size in points of the character.">
				<cocoa key="fontSize"/>
			</property>
		</class>
		
		<class name="attribute run" code="catr" description="This subdivides the text into chunks that all have the same attributes.">
			<cocoa class="NSTextStorage"/>
			<type type="text"/>
			<element type="paragraph"/>
			<element type="word"/>
			<element type="character"/>
			<element type="attachment"/>
			<property name="color" code="colr" type="RGB color" description="The color of the first character.">
				<cocoa key="foregroundColor"/>
			</property>
			<property name="font" code="font" type="text" description="The name of the font of the first character.">
				<cocoa key="fontName"/>
			</property>
			<property name="size" code="ptsz" type="number" description="The size in points of the first character.">
				<cocoa key="fontSize"/>
			</property>
		</class>
	
	</suite>
	
	<suite name="Mail" code="emal" description="Classes and commands for the Mail application">
	
		<command name="bounce" code="emalbcms" hidden="yes" description="Does nothing at all (deprecated)">
			<direct-parameter type="message" description="the message to bounce"/>
		</command>
		
		<command name="check for new mail" code="emalchma" description="Triggers a check for email.">
			<parameter name="for" code="acna" type="account" optional="yes" description="Specify the account that you wish to check for mail">
				<cocoa key="AccountName"/>
			</parameter>
		</command>
		<!--
		<command name="delete" code="coredelo" hidden="yes" description="Delete an object.">
			<cocoa class="MailDeleteCommand"/>
			<direct-parameter description="The object(s) to delete.">
				<type type="specifier" list="yes"/>
			</direct-parameter>
		</command>
		
		<command name="duplicate" code="coreclon" hidden="yes" description="Copy an object.">
			<cocoa class="MailCopyCommand"/>
			<direct-parameter description="The object(s) to copy.">
				<type type="specifier" list="yes"/>
			</direct-parameter>
			<parameter name="to" code="insh" type="location specifier" optional="yes" description="The location for the new copy or copies.">
				<cocoa key="ToLocation"/>
			</parameter>
			<parameter name="with properties" code="prdt" type="record" optional="yes" description="Properties to set in the new copy or copies right away.">
				<cocoa key="WithProperties"/>
			</parameter>
		</command>
		-->
		<command name="extract name from" code="emaleafn" description="Command to get the full name out of a fully specified email address. E.g. Calling this with &quot;John Doe &lt;jdoe@example.com&gt;&quot; as the direct object would return &quot;John Doe&quot;">
			<cocoa class="ExtractNameCommand"/>
			<direct-parameter type="text" description="fully formatted email address"/>
			<result type="text" description="the full name"/>
		</command>
		
		<command name="extract address from" code="emaleaua" description="Command to get just the email address of a fully specified email address. E.g. Calling this with &quot;John Doe &lt;jdoe@example.com&gt;&quot; as the direct object would return &quot;jdoe@example.com&quot;">
			<cocoa class="ExtractAddressCommand"/>
			<direct-parameter type="text" description="fully formatted email address"/>
			<result type="text" description="the email address"/>
		</command>
		
		<command name="forward" code="emalfwms" description="Creates a forwarded message.">
			<direct-parameter type="message" description="the message to forward"/>
			<parameter name="opening window" code="ropw" type="boolean" optional="yes" description="Whether the window for the forwarded message is shown. Default is to not show the window.">
				<cocoa key="OpeningWindow"/>
			</parameter>
			<result type="outgoing message" description="the message to be forwarded"/>
		</command>
		
		<command name="GetURL" code="emalemtg" description="Opens a mailto URL.">
			<cocoa class="MailToCommand"/>
			<direct-parameter type="text" description="the mailto URL"/>
		</command>
		
		<command name="import Mail mailbox" code="emalimmx" description="Imports a mailbox created by Mail.">
			<parameter name="at" code="mbpt" type="file" description="the mailbox or folder of mailboxes to import">
				<cocoa key="MboxPath"/>
			</parameter>
		</command>
		
		<command name="mailto" code="emalemto" description="Opens a mailto URL.">
			<cocoa class="MailToCommand"/>
			<direct-parameter type="text" description="the mailto URL"/>
		</command>
		<!--
		<command name="move" code="coremove" hidden="yes" description="Move an object to a new location.">
			<cocoa class="MailMoveCommand"/>
			<direct-parameter description="The object(s) to move.">
				<type type="specifier" list="yes"/>
			</direct-parameter>
			<parameter name="to" code="insh" type="location specifier" description="The new location for the object(s).">
				<cocoa key="ToLocation"/>
			</parameter>
		</command>
		-->
		<command name="perform mail action with messages" code="emalcpma" description="Script handler invoked by rules and menus that execute AppleScripts. The direct parameter of this handler is a list of messages being acted upon.">
			<direct-parameter description="the message being acted upon">
				<type type="message" list="yes"/>
			</direct-parameter>
			<parameter name="in mailboxes" code="pmbx" type="mailbox" optional="yes" description="If the script is being executed by the user selecting an item in the scripts menu, this argument will specify the mailboxes that are currently selected. Otherwise it will not be specified.">
				<cocoa key="Mailboxes"/>
			</parameter>
			<parameter name="for rule" code="pmar" type="rule" optional="yes" description="If the script is being executed by a rule action, this argument will be the rule being invoked. Otherwise it will not be specified.">
				<cocoa key="Rule"/>
			</parameter>
		</command>
		
		<command name="redirect" code="emalrdms" description="Creates a redirected message.">
			<direct-parameter type="message" description="the message to redirect"/>
			<parameter name="opening window" code="ropw" type="boolean" optional="yes" description="Whether the window for the redirected message is shown. Default is to not show the window.">
				<cocoa key="OpeningWindow"/>
			</parameter>
			<result type="outgoing message" description="the redirected message"/>
		</command>
		
		<command name="reply" code="emalrpms" description="Creates a reply message.">
			<direct-parameter type="message" description="the message to reply to"/>
			<parameter name="opening window" code="ropw" type="boolean" optional="yes" description="Whether the window for the reply message is shown. Default is to not show the window.">
				<cocoa key="OpeningWindow"/>
			</parameter>
			<parameter name="reply to all" code="rpal" type="boolean" optional="yes" description="Whether to reply to all recipients. Default is to reply to the sender only.">
				<cocoa key="ReplyToAll"/>
			</parameter>
			<result type="outgoing message" description="the reply message"/>
		</command>
		
		<command name="send" code="emsgsend" description="Sends a message.">
			<direct-parameter type="outgoing message" description="the message to send"/>
			<result type="boolean" description="true if sending was successful, false if not"/>
		</command>
		
		<command name="synchronize" code="emalsyac" description="Command to trigger synchronizing of an IMAP account with the server.">
			<parameter name="with" code="acna" type="account" description="The account to synchronize">
				<cocoa key="AccountName"/>
			</parameter>
		</command>
		
		<class name="outgoing message" code="bcke" description="A new email message">
			<cocoa class="ComposeBackEnd_Scripting"/>
			<access-group identifier="com.apple.mail.compose" access="rw"/>
			<element type="bcc recipient"/>
			<element type="cc recipient"/>
			<element type="recipient"/>
			<element type="to recipient"/>
			<property name="sender" code="sndr" type="text" description="The sender of the message">
				<cocoa key="appleScriptSender"/>
			</property>
			<property name="subject" code="subj" type="text" description="The subject of the message">
				<cocoa key="appleScriptSubject"/>
			</property>
			<contents name="content" code="ctnt" type="rich text" description="The contents of the message"/>
			<property name="visible" code="pvis" type="boolean" description="Controls whether the message window is shown on the screen. The default is false">
				<cocoa key="isVisible"/>
			</property>
			<property name="message signature" code="tnrg" description="The signature of the message">
				<type type="signature"/>
				<type type="missing value"/>
			</property>
			<property name="id" code="ID  " type="integer" access="r" description="The unique identifier of the message">
				<cocoa key="uniqueID"/>
			</property>
			<property name="html content" code="htda" type="text" access="w" hidden="yes" description="Does nothing at all (deprecated)"/>
			<property name="vcard path" code="htvc" type="file" access="w" hidden="yes" description="Does nothing at all (deprecated)"/>
			<responds-to command="save">
				<cocoa method="handleSaveMessageCommand:"/>
			</responds-to>
			<responds-to command="close">
				<cocoa method="handleCloseScriptCommand:"/>
			</responds-to>
			<responds-to command="send">
				<cocoa method="handleSendMessageCommand:"/>
			</responds-to>
		</class>
		
		<class name="ldap server" code="ldse" hidden="yes" description="DEPRECATED - DO NOT USE">
			<cocoa class="LDAPServer"/>
			<property name="enabled" code="isac" type="boolean" description="Does nothing at all (deprecated)"/>
			<property name="name" code="pnam" type="text" description="Does nothing at all (deprecated)">
				<cocoa key="entryName"/>
			</property>
			<property name="port" code="port" type="integer" description="Does nothing at all (deprecated)"/>
			<property name="scope" code="ldsc" type="LdapScope" description="Does nothing at all (deprecated)"/>
			<property name="search base" code="ldsb" type="text" description="Does nothing at all (deprecated)"/>
			<property name="host name" code="ldsa" type="text" description="Does nothing at all (deprecated)">
				<cocoa key="serverAddress"/>
			</property>
		</class>
		
		<class-extension extends="application" description="Mail's top level scripting object.">
			<cocoa class="MailApp"/>
			<element type="account"/>
			<element type="pop account"/>
			<element type="imap account"/>
			<element type="iCloud account">
				<cocoa key="aosImapAccounts"/>
			</element>
			<element type="smtp server">
				<cocoa key="deliveryAccounts"/>
			</element>
			<element type="outgoing message">
				<cocoa key="composeMessages"/>
				<access-group identifier="com.apple.mail.compose" access="rw"/>
			</element>
			<element type="ldap server" hidden="yes"/>
			<element type="mailbox"/>
			<element type="OLD message editor" hidden="yes">
				<cocoa key="messageEditors"/>
			</element>
			<element type="message viewer"/>
			<element type="rule"/>
			<element type="signature">
				<access-group identifier="com.apple.mail.compose" access="r"/>
			</element>
			<property name="always bcc myself" code="abcm" type="boolean" description="Indicates whether you will be included in the Bcc: field of messages which you are composing">
				<cocoa key="alwaysBCCMyself"/>
			</property>
			<property name="always cc myself" code="accm" type="boolean" description="Indicates whether you will be included in the Cc: field of messages which you are composing">
				<cocoa key="alwaysCCMyself"/>
			</property>
			<property name="selection" code="slct" access="r" description="List of messages that the user has selected">
				<cocoa key="applescriptSelection"/>
				<type type="message" list="yes"/>
			</property>
			<property name="application version" code="apve" type="text" access="r" description="The build number of the application"/>
			<property name="fetch interval" code="affq" type="integer" description="The interval (in minutes) between automatic fetches of new mail, -1 means to use an automatically determined interval">
				<cocoa key="autoFetchFrequency"/>
			</property>
			<property name="background activity count" code="bthc" type="integer" access="r" description="Number of background activities currently running in Mail, according to the Activity window">
				<cocoa key="backgroundThreadCount"/>
			</property>
			<property name="choose signature when composing" code="cswc" type="boolean" description="Indicates whether user can choose a signature directly in a new compose window"/>
			<property name="color quoted text" code="mcct" type="boolean" description="Indicates whether quoted text should be colored"/>
			<property name="default message format" code="demf" type="DefaultMessageFormat" description="Default format for messages being composed or message replies"/>
			<property name="download html attachments" code="dhta" type="boolean" description="Indicates whether images and attachments in HTML messages should be downloaded and displayed">
				<cocoa key="downloadHTMLAttachments"/>
			</property>
			<property name="drafts mailbox" code="drmb" type="mailbox" access="r" description="The top level Drafts mailbox"/>
			<property name="expand group addresses" code="exga" type="boolean" description="Indicates whether group addresses will be expanded when entered into the address fields of a new compose message"/>
			<property name="fixed width font" code="mptf" type="text" description="Font for plain text messages, only used if 'use fixed width font' is set to true"/>
			<property name="fixed width font size" code="ptfs" type="real" description="Font size for plain text messages, only used if 'use fixed width font' is set to true"/>
			<property name="framework version" code="frve" type="text" access="r" hidden="yes" description="Returns the same thing as application version (deprecated)"/>
			<property name="header detail" code="hedl" type="HeaderDetail" hidden="yes" description="This always returns default, and setting it doesn't do anything (deprecated)"/>
			<property name="inbox" code="inmb" type="mailbox" access="r" description="The top level In mailbox"/>
			<property name="include all original message text" code="iaoo" type="boolean" description="Indicates whether all of the original message will be quoted or only the text you have selected (if any)">
				<cocoa key="includeAllOfOriginalMessage"/>
			</property>
			<property name="quote original message" code="inom" type="boolean" description="Indicates whether the text of the original message will be included in replies">
				<cocoa key="includeOriginalMessage"/>
			</property>
			<property name="check spelling while typing" code="chsp" type="boolean" description="Indicates whether spelling will be checked automatically in messages being composed">
				<cocoa key="inlineSpellCheckingEnabled"/>
			</property>
			<property name="junk mailbox" code="jkmb" type="mailbox" access="r" description="The top level Junk mailbox"/>
			<property name="level one quoting color" code="loqc" type="QuotingColor" description="Color for quoted text with one level of indentation"/>
			<property name="level two quoting color" code="lwqc" type="QuotingColor" description="Color for quoted text with two levels of indentation"/>
			<property name="level three quoting color" code="lhqc" type="QuotingColor" description="Color for quoted text with three levels of indentation"/>
			<property name="message font" code="mmfn" type="text" description="Font for messages (proportional font)"/>
			<property name="message font size" code="mmfs" type="real" description="Font size for messages (proportional font)"/>
			<property name="message list font" code="mmlf" type="text" description="Font for message list"/>
			<property name="message list font size" code="mlfs" type="real" description="Font size for message list"/>
			<property name="new mail sound" code="mnms" type="text" description="Name of new mail sound or 'None' if no sound is selected"/>
			<property name="outbox" code="oumb" type="mailbox" access="r" description="The top level Out mailbox"/>
			<property name="should play other mail sounds" code="poms" type="boolean" description="Indicates whether sounds will be played for various things such as when a messages is sent or if no mail is found when manually checking for new mail or if there is a fetch error"/>
			<property name="same reply format" code="risf" type="boolean" description="Indicates whether replies will be in the same text format as the message to which you are replying">
				<cocoa key="replyInSameFormat"/>
			</property>
			<property name="selected signature" code="sesi" type="text" description="Name of current selected signature (or 'randomly', 'sequentially', or 'none')"/>
			<property name="sent mailbox" code="stmb" type="mailbox" access="r" description="The top level Sent mailbox"/>
			<property name="fetches automatically" code="saft" type="boolean" description="Indicates whether mail will automatically be fetched at a specific interval">
				<cocoa key="shouldAutoFetch"/>
			</property>
			<property name="highlight selected conversation" code="shht" type="boolean" description="Indicates whether messages in conversations should be highlighted in the Mail viewer window when not grouped">
				<cocoa key="shouldHighlightThreads"/>
			</property>
			<property name="trash mailbox" code="trmb" type="mailbox" access="r" description="The top level Trash mailbox"/>
			<property name="use address completion" code="usla" type="boolean" description="This always returns true, and setting it doesn't do anything (deprecated)"/>
			<property name="use fixed width font" code="ufwf" type="boolean" description="Should fixed-width font be used for plain text messages?"/>
			<property name="primary email" code="ueml" type="text" access="r" description="The user's primary email address">
				<cocoa key="userEmail"/>
			</property>
			<property name="hosts to log activity on" code="laoh" hidden="yes" description="Indicates whether to log socket activity for the specified hosts">
				<cocoa key="logActivityOnHosts"/>
				<type type="text" list="yes"/>
			</property>
			<property name="ports to log activity on" code="laop" hidden="yes" description="Indicates whether to log socket activity for the specified ports">
				<cocoa key="logActivityOnPorts"/>
				<type type="integer" list="yes"/>
			</property>
			<property name="log all socket activity" code="laas" type="boolean" hidden="yes" description="Indicates whether all socket activity will be logged"/>
			<property name="memory statistics" code="mems" type="record" access="r" hidden="yes"/>
			<property name="use keychain" code="uske" type="boolean" hidden="yes" description="Ignored - Mail always uses the Keychain to store passwords"/>
			<responds-to command="check for new mail">
				<cocoa method="handleCheckMailCommand:"/>
			</responds-to>
			<responds-to command="import Mail mailbox">
				<cocoa method="handleImportMboxCommand:"/>
			</responds-to>
			<responds-to command="synchronize">
				<cocoa method="handleSynchronizeAccountCommand:"/>
			</responds-to>
		</class-extension>
		
		<class name="OLD message editor" code="medt" hidden="yes" description="DEPRECATED - DO NOT USE">
			<cocoa class="MessageEditor"/>
			<property name="OLD compose message" code="bcke" type="outgoing message" description="DEPRECATED - DO NOT USE">
				<cocoa key="backEnd"/>
			</property>
		</class>
		
		<class name="message viewer" code="mvwr" description="Represents the object responsible for managing a viewer window">
			<cocoa class="MessageViewer"/>
			<element type="message">
				<cocoa key="allMessages"/>
			</element>
			<property name="drafts mailbox" code="drmb" type="mailbox" access="r" description="The top level Drafts mailbox"/>
			<property name="inbox" code="inmb" type="mailbox" access="r" description="The top level In mailbox"/>
			<property name="junk mailbox" code="jkmb" type="mailbox" access="r" description="The top level Junk mailbox"/>
			<property name="outbox" code="oumb" type="mailbox" access="r" description="The top level Out mailbox"/>
			<property name="sent mailbox" code="stmb" type="mailbox" access="r" description="The top level Sent mailbox"/>
			<property name="trash mailbox" code="trmb" type="mailbox" access="r" description="The top level Trash mailbox"/>
			<property name="sort column" code="mvsc" type="ViewerColumns" description="The column that is currently sorted in the viewer">
				<cocoa key="appleScriptSortColumn"/>
			</property>
			<property name="sorted ascending" code="mvsr" type="boolean" description="Whether the viewer is sorted ascending or not">
				<cocoa key="isSortedAscending"/>
			</property>
			<property name="mailbox list visible" code="mlsh" type="boolean" description="Controls whether the list of mailboxes is visible or not">
				<cocoa key="mailboxesPaneIsOpen"/>
			</property>
			<property name="preview pane is visible" code="mvpv" type="boolean" description="Controls whether the preview pane of the message viewer window is visible or not">
				<cocoa key="previewPaneVisible"/>
			</property>
			<property name="visible columns" code="mvvc" description="List of columns that are visible. The subject column and the message status column will always be visible">
				<type type="ViewerColumns" list="yes"/>
			</property>
			<property name="id" code="ID  " type="integer" access="r" description="The unique identifier of the message viewer">
				<cocoa key="uniqueID"/>
			</property>
			<property name="visible messages" code="mvfm" description="List of messages currently being displayed in the viewer">
				<cocoa key="focusedMessages"/>
				<type type="message" list="yes"/>
			</property>
			<property name="selected messages" code="smgs" description="List of messages currently selected">
				<type type="message" list="yes"/>
			</property>
			<property name="selected mailboxes" code="msbx" description="List of mailboxes currently selected in the list of mailboxes">
				<type type="mailbox" list="yes"/>
			</property>
			<contents name="window" code="cwin" type="window" description="The window for the message viewer"/>
		</class>
		
		<class name="signature" code="situ" description="Email signatures">
			<cocoa class="MFSignature"/>
			<access-group identifier="com.apple.mail.compose" access="r"/>
			<property name="content" code="ctnt" type="text" description="Contents of email signature. If there is a version with fonts and/or styles, that will be returned over the plain text version">
				<cocoa key="signatureContents"/>
			</property>
			<property name="name" code="pnam" type="text" description="Name of the signature">
				<cocoa key="signatureName"/>
			</property>
		</class>
		
		<!--
			This enumeration is used by the "save" command in the imported Cocoa Standard suite. We don't really
			support saving items in different formats, but if we don't declare a "saveable file format" type then
			we get a runtime error. It would make sense for the "message" class to respond to the "save" command,
			and then we would probably want to allow different formats, <rdar://problem/4451553>.
		-->
		<enumeration name="saveable file format" code="savf">
			<enumerator name="native format" code="item" description="Native format">
				<cocoa string-value="public.item"/>
			</enumerator>
		</enumeration>
		
		<enumeration name="DefaultMessageFormat" code="edmf">
			<enumerator name="plain format" code="dmpt" description="Plain Text"/>
			<enumerator name="rich format" code="dmrt" description="Rich Text"/>
		</enumeration>
		
		<enumeration name="HeaderDetail" code="hede" hidden="yes">
			<enumerator name="all" code="hdal" description="All"/>
			<enumerator name="custom" code="hdcu" description="Custom"/>
			<enumerator name="default" code="hdde" description="Default"/>
			<enumerator name="no headers" code="hdnn" description="No headers"/>
		</enumeration>
		
		<enumeration name="LdapScope" code="ldas" hidden="yes">
			<enumerator name="base" code="lsba" description="LDAP scope of 'Base'"/>
			<enumerator name="one level" code="lsol" description="LDAP scope of 'One Level'"/>
			<enumerator name="subtree" code="lsst" description="LDAP scope of 'Subtree'"/>
		</enumeration>
		
		<enumeration name="QuotingColor" code="qqcl">
			<enumerator name="blue" code="ccbl" description="Blue"/>
			<enumerator name="green" code="ccgr" description="Green"/>
			<enumerator name="orange" code="ccor" description="Orange"/>
			<enumerator name="other" code="ccot" description="Other"/>
			<enumerator name="purple" code="ccpu" description="Purple"/>
			<enumerator name="red" code="ccre" description="Red"/>
			<enumerator name="yellow" code="ccye" description="Yellow"/>
		</enumeration>
		
		<enumeration name="ViewerColumns" code="mvcl">
			<enumerator name="attachments column" code="ecat" description="Column containing the number of attachments a message contains"/>
			<enumerator name="message color" code="eccl" description="Used to indicate sorting should be done by color"/>
			<enumerator name="date received column" code="ecdr" description="Column containing the date a message was received"/>
			<enumerator name="date sent column" code="ecds" description="Column containing the date a message was sent"/>
			<enumerator name="flags column" code="ecfl" description="Column containing the flags of a message"/>
			<enumerator name="from column" code="ecfr" description="Column containing the sender's name"/>
			<enumerator name="mailbox column" code="ecmb" description="Column containing the name of the mailbox or account a message is in"/>
			<enumerator name="message status column" code="ecms" description="Column indicating a messages status (read, unread, replied to, forwarded, etc)"/>
			<enumerator name="number column" code="ecnm" description="Column containing the number of a message in a mailbox"/>
			<enumerator name="size column" code="ecsz" description="Column containing the size of a message"/>
			<enumerator name="subject column" code="ecsu" description="Column containing the subject of a message"/>
			<enumerator name="to column" code="ecto" description="Column containing the recipients of a message"/>
			<enumerator name="date last saved column" code="ecls" description="Column containing the date a draft message was saved"/>
		</enumeration>
	
	</suite>
	
	<suite name="Mail Framework" code="emsg" description="Classes and commands for the Mail framework">
	
		<class name="message" code="mssg" description="An email message">
			<cocoa class="MCMessage"/>
			<element type="bcc recipient"/>
			<element type="cc recipient"/>
			<element type="recipient"/>
			<element type="to recipient"/>
			<element type="header">
				<cocoa key="appleScriptHeaders"/>
			</element>
			<element type="mail attachment">
				<cocoa key="appleScriptAttachments"/>
			</element>
			<property name="id" code="ID  " type="integer" access="r" description="The unique identifier of the message.">
				<cocoa key="libraryID"/>
			</property>
			<property name="all headers" code="alhe" type="text" access="r" description="All the headers of the message"/>
			<property name="background color" code="mcol" type="HighlightColors" description="The background color of the message"/>
			<property name="mailbox" code="mbxp" type="mailbox" description="The mailbox in which this message is filed">
				<cocoa key="container"/>
			</property>
			<property name="content" code="ctnt" type="rich text" access="r" description="Contents of an email message"/>
			<property name="date received" code="rdrc" type="date" access="r" description="The date a message was received"/>
			<property name="date sent" code="drcv" type="date" access="r" description="The date a message was sent"/>
			<property name="deleted status" code="isdl" type="boolean" description="Indicates whether the message is deleted or not">
				<cocoa key="isDeleted"/>
			</property>
			<property name="flagged status" code="isfl" type="boolean" description="Indicates whether the message is flagged or not">
				<cocoa key="isFlagged"/>
			</property>
			<property name="flag index" code="fidx" type="integer" description="The flag on the message, or -1 if the message is not flagged">
				<cocoa key="flaggedStatus"/>
			</property>
			<property name="junk mail status" code="isjk" type="boolean" description="Indicates whether the message has been marked junk or evaluated to be junk by the junk mail filter.">
				<cocoa key="isJunk"/>
			</property>
			<property name="read status" code="isrd" type="boolean" description="Indicates whether the message is read or not">
				<cocoa key="isRead"/>
			</property>
			<property name="message id" code="meid" type="text" access="r" description="The unique message ID string">
				<cocoa key="scriptedMessageIDHeader"/>
			</property>
			<property name="source" code="raso" type="text" access="r" description="Raw source of the message">
				<cocoa key="rawSource"/>
			</property>
			<property name="reply to" code="rpto" type="text" access="r" description="The address that replies should be sent to"/>
			<property name="message size" code="msze" type="integer" access="r" description="The size (in bytes) of a message">
				<cocoa key="scriptedMessageSize"/>
			</property>
			<property name="sender" code="sndr" type="text" access="r" description="The sender of the message"/>
			<property name="subject" code="subj" type="text" access="r" description="The subject of the message">
				<cocoa key="subjectString"/>
			</property>
			<property name="was forwarded" code="isfw" type="boolean" access="r" description="Indicates whether the message was forwarded or not"/>
			<property name="was redirected" code="isrc" type="boolean" access="r" description="Indicates whether the message was redirected or not"/>
			<property name="was replied to" code="isrp" type="boolean" access="r" description="Indicates whether the message was replied to or not"/>
			<responds-to command="open">
				<cocoa method="handleOpenAppleEvent:"/>
			</responds-to>
			<responds-to command="bounce">
				<cocoa method="handleBounceMessage:"/>
			</responds-to>
			<responds-to command="forward">
				<cocoa method="handleForwardMessage:"/>
			</responds-to>
			<responds-to command="redirect">
				<cocoa method="handleRedirectMessage:"/>
			</responds-to>
			<responds-to command="reply">
				<cocoa method="handleReplyToMessage:"/>
			</responds-to>
		</class>
		
		<class name="account" code="mact" description="A Mail account for receiving messages (POP/IMAP). To create a new receiving account, use the 'pop account', 'imap account', and 'iCloud account' objects">
			<cocoa class="MFMailAccount"/>
			<element type="mailbox"/>
			<property name="delivery account" code="dact" description="The delivery account used when sending mail from this account">
				<type type="smtp server"/>
				<type type="missing value"/>
			</property>
			<property name="name" code="pnam" type="text" description="The name of an account">
				<cocoa key="accountName"/>
			</property>
			<property name="id" code="ID  " type="text" access="r" description="The unique identifier of the account">
				<cocoa key="identifier"/>
			</property>
			<property name="password" code="macp" type="text" description="Password for this account. Can be set, but not read via scripting">
				<cocoa key="accountPassword"/>
			</property>
			<property name="authentication" code="paus" type="Authentication" description="Preferred authentication scheme for account">
				<cocoa key="customAuthentication"/>
			</property>
			<property name="account type" code="atyp" type="TypeOfAccount" access="r" description="The type of an account"/>
			<property name="email addresses" code="emad" description="The list of email addresses configured for an account">
				<cocoa key="applescriptEmailAddresses"/>
				<type type="text" list="yes"/>
			</property>
			<property name="full name" code="flln" type="text" description="The users full name configured for an account">
				<cocoa key="applescriptFullUserName"/>
			</property>
			<property name="empty junk messages frequency" code="ejmf" type="integer" description="Number of days before junk messages are deleted (0 = delete on quit, -1 = never delete)">
				<cocoa key="emptyJunkFrequency"/>
			</property>
			<property name="empty sent messages frequency" code="esmf" type="integer" hidden="yes" description="Does nothing at all (deprecated)"/>
			<property name="empty trash frequency" code="etrf" type="integer" description="Number of days before messages in the trash are permanently deleted (0 = delete on quit, -1 = never delete)"/>
			<property name="empty junk messages on quit" code="ejmo" type="boolean" description="Indicates whether the messages in the junk messages mailboxes will be deleted on quit">
				<cocoa key="emptyJunkOnQuit"/>
			</property>
			<property name="empty sent messages on quit" code="esmo" type="boolean" hidden="yes" description="Does nothing at all (deprecated)"/>
			<property name="empty trash on quit" code="etoq" type="boolean" description="Indicates whether the messages in deleted messages mailboxes will be permanently deleted on quit"/>
			<property name="enabled" code="isac" type="boolean" description="Indicates whether the account is enabled or not">
				<cocoa key="isActive"/>
			</property>
			<property name="user name" code="unme" type="text" description="The user name used to connect to an account">
				<cocoa key="loginName"/>
			</property>
			<property name="account directory" code="path" type="file" access="r" description="The directory where the account stores things on disk"/>
			<property name="port" code="port" type="integer" description="The port used to connect to an account">
				<cocoa key="portNumber"/>
			</property>
			<property name="server name" code="host" type="text" description="The host name used to connect to an account"/>
			<property name="include when getting new mail" code="iwgm" type="boolean" hidden="yes" description="Does nothing at all (deprecated)">
				<cocoa key="shouldAutoFetch"/>
			</property>
			<property name="move deleted messages to trash" code="smdm" type="boolean" description="Indicates whether messages that are deleted will be moved to the trash mailbox">
				<cocoa key="shouldMoveDeletedMessagesToTrash"/>
			</property>
			<property name="uses ssl" code="usss" type="boolean" description="Indicates whether SSL is enabled for this receiving account">
				<cocoa key="usesSSL"/>
			</property>
		</class>
		
		<class name="imap account" code="iact" inherits="account" description="An IMAP email account">
			<cocoa class="MFIMAPAccount"/>
			<property name="compact mailboxes when closing" code="cwcm" type="boolean" description="Indicates whether an IMAP mailbox is automatically compacted when you quit Mail or switch to another mailbox">
				<cocoa key="compactWhenClosingMailboxes"/>
			</property>
			<property name="message caching" code="msgc" type="MessageCachingPolicy" description="Message caching setting for this account"/>
			<property name="store drafts on server" code="sdos" type="boolean" description="Indicates whether drafts will be stored on the IMAP server"/>
			<property name="store junk mail on server" code="sjos" type="boolean" description="Indicates whether junk mail will be stored on the IMAP server">
				<cocoa key="storeJunkOnServer"/>
			</property>
			<property name="store sent messages on server" code="ssos" type="boolean" description="Indicates whether sent messages will be stored on the IMAP server"/>
			<property name="store deleted messages on server" code="stos" type="boolean" description="Indicates whether deleted messages will be stored on the IMAP server">
				<cocoa key="storeTrashOnServer"/>
			</property>
		</class>
		
		<class name="iCloud account" code="itac" inherits="imap account" description="An iCloud or MobileMe email account">
			<cocoa class="MFAosImapAccount"/>
			<synonym name="Mac account"/>
			<synonym name="MobileMe account"/>
		</class>
		
		<class name="pop account" code="pact" inherits="account" description="A POP email account">
			<cocoa class="MFPOPAccount"/>
			<property name="big message warning size" code="bmws" type="integer" description="If message size (in bytes) is over this amount, Mail will prompt you asking whether you want to download the message (-1 = do not prompt)"/>
			<property name="delayed message deletion interval" code="dmdi" type="integer" description="Number of days before messages that have been downloaded will be deleted from the server (0 = delete immediately after downloading)"/>
			<property name="delete mail on server" code="dmos" type="boolean" description="Indicates whether POP account deletes messages on the server after downloading">
				<cocoa key="deleteMessagesOnServer"/>
			</property>
			<property name="delete messages when moved from inbox" code="dmwm" type="boolean" description="Indicates whether messages will be deleted from the server when moved from your POP inbox"/>
		</class>
		
		<class name="smtp server" code="dact" description="An SMTP account (for sending email)">
			<cocoa class="MFSMTPAccount"/>
			<property name="name" code="pnam" type="text" access="r" description="The name of an account">
				<cocoa key="accountName"/>
			</property>
			<property name="password" code="macp" type="text" description="Password for this account. Can be set, but not read via scripting">
				<cocoa key="accountPassword"/>
			</property>
			<property name="account type" code="atyp" type="TypeOfAccount" access="r" description="The type of an account"/>
			<property name="authentication" code="paus" type="Authentication" description="Preferred authentication scheme for account">
				<cocoa key="customAuthentication"/>
			</property>
			<property name="enabled" code="isac" type="boolean" description="Indicates whether the account is enabled or not">
				<cocoa key="isActive"/>
			</property>
			<property name="user name" code="unme" type="text" description="The user name used to connect to an account">
				<cocoa key="loginName"/>
			</property>
			<property name="port" code="port" type="integer" description="The port used to connect to an account">
				<cocoa key="portNumber"/>
			</property>
			<property name="server name" code="host" type="text" description="The host name used to connect to an account"/>
			<property name="uses ssl" code="usss" type="boolean" description="Indicates whether SSL is enabled for this receiving account">
				<cocoa key="usesSSL"/>
			</property>
		</class>
		
		<class name="mailbox" code="mbxp" plural="mailboxes" description="A mailbox that holds messages">
			<cocoa class="MFMailbox"/>
			<element type="mailbox">
				<cocoa key="applescriptChildren"/>
			</element>
			<element type="message"/>
			<property name="name" code="pnam" type="text" description="The name of a mailbox">
				<cocoa key="mailboxName"/>
			</property>
			<property name="unread count" code="mbuc" type="integer" access="r" description="The number of unread messages in the mailbox">
				<cocoa key="displayCount"/>
			</property>
			<property name="account" code="mact" type="account" access="r">
				<cocoa key="applescriptAccount"/>
			</property>
			<property name="container" code="mbxc" type="mailbox" access="r">
				<cocoa key="applescriptContainer"/>
			</property>
		</class>
		
		<class name="rule" code="rule" description="Class for message rules">
			<cocoa class="MFMessageRule"/>
			<element type="rule condition">
				<cocoa key="criteria"/>
			</element>
			<property name="color message" code="rcme" type="HighlightColors" description="If rule matches, apply this color">
				<cocoa key="actionColorMessage"/>
			</property>
			<property name="delete message" code="rdme" type="boolean" description="If rule matches, delete message">
				<cocoa key="actionDeleteMessage"/>
			</property>
			<property name="forward text" code="rfte" type="text" description="If rule matches, prepend this text to the forwarded message. Set to empty string to include no prepended text">
				<cocoa key="actionForwardText"/>
			</property>
			<property name="forward message" code="rfad" type="text" description="If rule matches, forward message to this address, or multiple addresses, separated by commas. Set to empty string to disable this action">
				<cocoa key="actionForwardToAddress"/>
			</property>
			<property name="mark flagged" code="rmfl" type="boolean" description="If rule matches, mark message as flagged">
				<cocoa key="actionMarkAsFlagged"/>
			</property>
			<property name="mark flag index" code="rfcl" type="integer" description="If rule matches, mark message with the specified flag. Set to -1 to disable this action">
				<cocoa key="actionMarkAsFlaggedStatus"/>
			</property>
			<property name="mark read" code="rmre" type="boolean" description="If rule matches, mark message as read">
				<cocoa key="actionMarkAsRead"/>
			</property>
			<property name="play sound" code="rpso" type="text" description="If rule matches, play this sound (specify name of sound or path to sound)"/>
			<property name="redirect message" code="rrad" type="text" description="If rule matches, redirect message to this address or multiple addresses, separate by commas. Set to empty string to disable this action">
				<cocoa key="actionRedirectToAddress"/>
			</property>
			<property name="reply text" code="rrte" type="text" description="If rule matches, reply to message and prepend with this text. Set to empty string to disable this action">
				<cocoa key="actionReplyText"/>
			</property>
			<property name="run script" code="rras" description="If rule matches, run this compiled AppleScript file. Set to empty string to disable this action">
				<cocoa key="actionRunApplescript"/>
				<type type="file"/>
				<type type="missing value"/>
			</property>
			<property name="all conditions must be met" code="racm" type="boolean" description="Indicates whether all conditions must be met for rule to execute">
				<cocoa key="allCriteriaMustBeSatisfied"/>
			</property>
			<property name="copy message" code="rcmb" type="mailbox" description="If rule matches, copy to this mailbox">
				<cocoa key="appleScriptCopyDestinationMailbox"/>
			</property>
			<property name="move message" code="rtme" type="mailbox" description="If rule matches, move to this mailbox">
				<cocoa key="appleScriptDestinationMailbox"/>
			</property>
			<property name="highlight text using color" code="htuc" type="boolean" description="Indicates whether the color will be used to highlight the text or background of a message in the message list"/>
			<property name="enabled" code="isac" type="boolean" description="Indicates whether the rule is enabled">
				<cocoa key="isActive"/>
			</property>
			<property name="name" code="pnam" type="text" description="Name of rule">
				<cocoa key="ruleDescription"/>
			</property>
			<property name="should copy message" code="rscm" type="boolean" description="Indicates whether the rule has a copy action"/>
			<property name="should move message" code="rstm" type="boolean" description="Indicates whether the rule has a move action">
				<cocoa key="shouldTransferMessage"/>
			</property>
			<property name="stop evaluating rules" code="rser" type="boolean" description="If rule matches, stop rule evaluation for this message">
				<cocoa key="shouldStopEvaluatingRules"/>
			</property>
		</class>
		
		<class name="rule condition" code="rucr" description="Class for conditions that can be attached to a single rule">
			<cocoa class="MFMessageRuleCriterion"/>
			<property name="expression" code="rexp" type="text" description="Rule expression field">
				<cocoa key="ruleExpression"/>
			</property>
			<property name="header" code="rhed" type="text" description="Rule header key">
				<cocoa key="ruleHeader"/>
			</property>
			<property name="qualifier" code="rqua" type="RuleQualifier" description="Rule qualifier">
				<cocoa key="ruleQualifier"/>
			</property>
			<property name="rule type" code="rtyp" type="RuleType" description="Rule type"/>
		</class>
		
		<class name="recipient" code="rcpt" description="An email recipient">
			<cocoa class="MFMessageAddressee"/>
			<access-group identifier="com.apple.mail.compose" access="rw"/>
			<property name="address" code="radd" type="text" description="The recipients email address"/>
			<property name="name" code="pnam" type="text" description="The name used for display">
				<cocoa key="displayName"/>
			</property>
		</class>
		
		<class name="bcc recipient" code="brcp" inherits="recipient" description="An email recipient in the Bcc: field">
			<cocoa class="MFMessageAddressee"/>
		</class>
		
		<class name="cc recipient" code="crcp" inherits="recipient" description="An email recipient in the Cc: field">
			<cocoa class="MFMessageAddressee"/>
		</class>
		
		<class name="to recipient" code="trcp" inherits="recipient" description="An email recipient in the To: field">
			<cocoa class="MFMessageAddressee"/>
		</class>
		
		<class name="container" code="mbxc" inherits="mailbox" description="A mailbox that contains other mailboxes.">
			<cocoa class="MFMailbox"/>
		</class>
		
		<class name="header" code="mhdr" description="A header value for a message. E.g. To, Subject, From.">
			<cocoa class="_MFAppleScriptHeaderRecord"/>
			<property name="content" code="ctnt" type="text" description="Contents of the header"/>
			<property name="name" code="pnam" type="text" description="Name of the header value"/>
		</class>
		
		<class name="mail attachment" code="attc" description="A file attached to a received message.">
			<cocoa class="MCAppleScriptAttachment"/>
			<property name="name" code="pnam" type="text" access="r" description="Name of the attachment" />
			<property name="MIME type" code="attp" type="text" access="r" description="MIME type of the attachment E.g. text/plain." />
			<property name="file size" code="atsz" type="integer" access="r" description="Approximate size in bytes." />
			<property name="downloaded" code="atdn" type="boolean" access="r" description="Indicates whether the attachment has been downloaded." />
			<property name="id" code="ID  " type="text" access="r" description="The unique identifier of the attachment.">
				<cocoa key="uniqueID"/>
			</property>
			<responds-to command="save">
				<cocoa method="handleSaveAttachmentCommand:"/>
			</responds-to>
		</class>
		
		<enumeration name="Authentication" code="exut">
			<enumerator name="password" code="axct" description="Clear text password"/>
			<enumerator name="apop" code="aapo" description="APOP"/>
			<enumerator name="kerberos 5" code="axk5" description="Kerberos V5 (GSSAPI)"/>
			<enumerator name="ntlm" code="axnt" description="NTLM"/>
			<enumerator name="md5" code="axmd" description="CRAM-MD5"/>
			<enumerator name="external" code="aext" description="External authentication (TLS client certificate)"/>
			<enumerator name="Apple token" code="atok" description="Apple token"/>
			<enumerator name="none" code="ccno" description="None"/>
		</enumeration>
		
		<enumeration name="HighlightColors" code="cclr">
			<enumerator name="blue" code="ccbl" description="Blue"/>
			<enumerator name="gray" code="ccgy" description="Gray"/>
			<enumerator name="green" code="ccgr" description="Green"/>
			<enumerator name="none" code="ccno" description="None"/>
			<enumerator name="orange" code="ccor" description="Orange"/>
			<enumerator name="other" code="ccot" description="Other"/>
			<enumerator name="purple" code="ccpu" description="Purple"/>
			<enumerator name="red" code="ccre" description="Red"/>
			<enumerator name="yellow" code="ccye" description="Yellow"/>
		</enumeration>
		
		<enumeration name="MessageCachingPolicy" code="e9xp">
			<enumerator name="do not keep copies of any messages" code="x9no" hidden="yes" description="Do not use this option (deprecated). If you do, Mail will use the 'all messages but omit attachments' policy"/>
			<enumerator name="only messages I have read" code="x9wr" hidden="yes" description="Do not use this option (deprecated). If you do, Mail will use the 'all messages but omit attachments' policy"/>
			<enumerator name="all messages but omit attachments" code="x9bo" description="All messages but omit attachments"/>
			<enumerator name="all messages and their attachments" code="x9al" description="All messages and their attachments"/>
		</enumeration>
		
		<enumeration name="RuleQualifier" code="enrq">
			<enumerator name="begins with value" code="rqbw" description="Begins with value"/>
			<enumerator name="does contain value" code="rqco" description="Does contain value"/>
			<enumerator name="does not contain value" code="rqdn" description="Does not contain value"/>
			<enumerator name="ends with value" code="rqew" description="Ends with value"/>
			<enumerator name="equal to value" code="rqie" description="Equal to value"/>
			<enumerator name="less than value" code="rqlt" description="Less than value"/>
			<enumerator name="greater than value" code="rqgt" description="Greater than value"/>
			<enumerator name="none" code="rqno" description="Indicates no qualifier is applicable"/>
		</enumeration>
		
		<enumeration name="RuleType" code="erut">
			<enumerator name="account" code="tacc" description="Account"/>
			<enumerator name="any recipient" code="tanr" description="Any recipient"/>
			<enumerator name="cc header" code="tccc" description="Cc header"/>
			<enumerator name="matches every message" code="tevm" description="Every message"/>
			<enumerator name="from header" code="tfro" description="From header"/>
			<enumerator name="header key" code="thdk" description="An arbitrary header key"/>
			<enumerator name="message content" code="tmec" description="Message content"/>
			<enumerator name="message is junk mail" code="tmij" description="Message is junk mail"/>
			<enumerator name="sender is in my contacts" code="tsii" description="Sender is in my contacts"/>
			<enumerator name="sender is in my previous recipients" code="tsah" description="Sender is in my previous recipients"/>
			<enumerator name="sender is member of group" code="tsim" description="Sender is member of group"/>
			<enumerator name="sender is not in my contacts" code="tsin" description="Sender is not in my contacts"/>
			<enumerator name="sender is not in my previous recipients" code="tnah" description="sender is not in my previous recipients"/>
			<enumerator name="sender is not member of group" code="tsig" description="Sender is not member of group"/>
			<enumerator name="sender is VIP" code="tsig" description="Sender is VIP"/>
			<enumerator name="subject header" code="tsub" description="Subject header"/>
			<enumerator name="to header" code="ttoo" description="To header"/>
			<enumerator name="to or cc header" code="ttoc" description="To or Cc header"/>
			<enumerator name="attachment type" code="tatt" description="Attachment Type"/>
		</enumeration>
		
		<enumeration name="TypeOfAccount" code="etoc">
			<enumerator name="pop" code="etpo" description="POP"/>
			<enumerator name="smtp" code="etsm" description="SMTP"/>
			<enumerator name="imap" code="etim" description="IMAP"/>
			<enumerator name="iCloud" code="etit" description="iCloud">
				<synonym name="Mac"/>
			</enumerator>
			<enumerator name="unknown" code="etun" hidden="yes" description="Unknown"/>
		</enumeration>
	
	</suite>
	
</dictionary>
