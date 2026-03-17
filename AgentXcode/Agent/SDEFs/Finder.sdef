<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE dictionary SYSTEM "file://localhost/System/Library/DTDs/sdef.dtd">

<dictionary>
	<suite name="Standard Suite" code="CoRe" description="Common terms that most applications should support">
		<command name="open" code="aevtodoc" description="Open the specified object(s)">
			<direct-parameter type="specifier" description="list of objects to open"/>
			<parameter name="using" code="usin" type="specifier" optional="yes" description="the application file to open the object with"/>
			<parameter name="with properties" code="prdt" type="record" optional="yes" description="the initial values for the properties, to be included with the open command sent to the application that opens the direct object"/>
		</command>
		<command name="print" code="aevtpdoc" description="Print the specified object(s)">
			<direct-parameter type="specifier" description="list of objects to print"/>
			<parameter name="with properties" code="prdt" type="record" optional="yes" description="optional properties to be included with the print command sent to the application that prints the direct object"/>
		</command>
		<command name="quit" code="aevtquit" description="Quit the Finder"/>
		<command name="activate" code="miscactv" description="Activate the specified window (or the Finder)">
			<direct-parameter type="specifier" optional="yes" description="the window to activate (if not specified, activates the Finder)"/>
		</command>
		<command name="close" code="coreclos" description="Close an object">
			<direct-parameter type="specifier" description="the object to close"/>
		</command>
		<command name="count" code="corecnte" description="Return the number of elements of a particular class within an object">
			<direct-parameter type="specifier" description="the object whose elements are to be counted"/>
			<parameter name="each" code="kocl" type="type" description="the class of the elements to be counted"/>
			<result type="integer" description="the number of elements"/>
		</command>
		<command name="data size" code="coredsiz" description="Return the size in bytes of an object">
			<direct-parameter type="specifier" description="the object whose data size is to be returned"/>
			<parameter name="as" code="rtyp" type="type" optional="yes" description="the data type for which the size is calculated"/>
			<result type="integer" description="the size of the object in bytes"/>
		</command>
		<command name="delete" code="coredelo" description="Move an item from its container to the trash">
			<direct-parameter type="specifier" description="the item to delete"/>
			<result type="specifier" description="to the item that was just deleted"/>
		</command>
		<command name="duplicate" code="coreclon" description="Duplicate one or more object(s)">
			<direct-parameter type="specifier" description="the object(s) to duplicate"/>
			<parameter name="to" code="insh" type="location specifier" optional="yes" description="the new location for the object(s)"/>
			<parameter name="replacing" code="alrp" type="boolean" optional="yes" description="Specifies whether or not to replace items in the destination that have the same name as items being duplicated"/>
			<parameter name="routing suppressed" code="rout" type="boolean" optional="yes" description="Specifies whether or not to autoroute items (default is false). Only applies when copying to the system folder."/>
			<parameter name="exact copy" code="exct" type="boolean" optional="yes" description="Specifies whether or not to copy permissions/ownership as is"/>
			<result type="specifier" description="to the duplicated object(s)"/>
		</command>
		<command name="exists" code="coredoex" description="Verify if an object exists">
			<direct-parameter type="specifier" description="the object in question"/>
			<result type="boolean" description="true if it exists, false if not"/>
		</command>
		<command name="make" code="corecrel" description="Make a new element">
			<parameter name="new" code="kocl" type="type" description="the class of the new element"/>
			<parameter name="at" code="insh" type="location specifier" description="the location at which to insert the element"/>
			<parameter name="to" code="to  " type="specifier" optional="yes" description="when creating an alias file, the original item to create an alias to or when creating a file viewer window, the target of the window"/>
			<parameter name="with properties" code="prdt" type="record" optional="yes" description="the initial values for the properties of the element"/>
			<result type="specifier" description="to the new object(s)"/>
		</command>
		<command name="move" code="coremove" description="Move object(s) to a new location">
			<direct-parameter type="specifier" description="the object(s) to move"/>
			<parameter name="to" code="insh" type="location specifier" description="the new location for the object(s)"/>
			<parameter name="replacing" code="alrp" type="boolean" optional="yes" description="Specifies whether or not to replace items in the destination that have the same name as items being moved"/>
			<parameter name="positioned at" code="mvpl" type="list" optional="yes" description="Gives a list (in local window coordinates) of positions for the destination items"/>
			<parameter name="routing suppressed" code="rout" type="boolean" optional="yes" description="Specifies whether or not to autoroute items (default is false). Only applies when moving to the system folder."/>
			<result type="specifier" description="to the object(s) after they have been moved"/>
		</command>
		<command name="select" code="miscslct" description="Select the specified object(s)">
			<direct-parameter type="specifier" description="the object to select"/>
		</command>
	</suite>

	<suite name="Finder Basics" code="fndr" description="Commonly-used Finder commands and object classes">

		<command name="openVirtualLocation" hidden="yes" code="fndrovir" description="Private event to open a virtual location">
			<access-group identifier="com.apple.private.siri"/>
			<direct-parameter type="text" description="the location to open">
				<access-group identifier="com.apple.private.siri"/>
			</direct-parameter>
		</command>
		<command name="copy" code="misccopy" description="(NOT AVAILABLE YET) Copy the selected items to the clipboard (the Finder must be the front application)"/>
		<command name="sort" code="DATASORT" description="Return the specified object(s) in a sorted list">
			<direct-parameter type="specifier" description="a list of finder objects to sort"/>
			<parameter name="by" code="by  " type="property" description="the property to sort the items by (name, index, date, etc.)"/>
			<result type="specifier" optional="yes" description="the sorted items in their new order"/>
		</command>
		<class name="application" code="capp" description="The Finder">
			<element type="item"/>
			<element type="container"/>
			<element type="disk"/>
			<element type="folder"/>
			<element type="file"/>
			<element type="alias file"/>
			<element type="application file"/>
			<element type="document file"/>
			<element type="internet location file"/>
			<element type="clipping"/>
			<element type="package"/>
			<element type="window"/>
			<element type="Finder window"/>
			<element type="clipping window"/>
			<property name="clipboard" code="pcli" type="specifier" access="r" description="(NOT AVAILABLE YET) the Finder’s clipboard window"/>
			<property name="name" code="pnam" type="text" access="r" description="the Finder’s name"/>
			<property name="visible" code="pvis" type="boolean" description="Is the Finder’s layer visible?"/>
			<property name="frontmost" code="pisf" type="boolean" description="Is the Finder the frontmost process?"/>
			<property name="selection" code="sele" type="specifier" description="the selection in the frontmost Finder window"/>
			<property name="insertion location" code="pins" type="specifier" access="r" description="the container in which a new folder would appear if “New Folder” was selected"/>
			<property name="product version" code="ver2" type="text" access="r" description="the version of the System software running on this computer"/>
			<property name="version" code="vers" type="text" access="r" description="the version of the Finder"/>
			<property name="startup disk" code="sdsk" type="disk" access="r" description="the startup disk"/>
			<property name="desktop" code="desk" type="desktop-object" access="r" description="the desktop"/>
			<property name="trash" code="trsh" type="trash-object" access="r" description="the trash"/>
			<property name="home" code="home" type="folder" access="r" description="the home directory"/>
			<property name="computer container" code="pcmp" type="computer-object" access="r" description="the computer location (as in Go > Computer)"/>
			<property name="Finder preferences" code="pfrp" type="preferences" access="r" description="Various preferences that apply to the Finder as a whole"/>
		</class>
	</suite>

	<suite name="Finder items" code="fndr" description="Commands used with file system items, and basic item definition">
		<command name="clean up" code="fndrfclu" description="Arrange items in window nicely (only applies to open windows in icon view that are not kept arranged)">
			<direct-parameter type="specifier" description="the window to clean up"/>
			<parameter name="by" code="by  " type="property" optional="yes" description="the order in which to clean up the objects (name, index, date, etc.)"/>
		</command>
		<command name="eject" code="fndrejct" description="Eject the specified disk(s)">
			<direct-parameter type="specifier" optional="yes" description="the disk(s) to eject"/>
		</command>
		<command name="empty" code="fndrempt" description="Empty the trash">
			<access-group identifier="com.apple.finder.trash"/>
			<direct-parameter type="specifier" optional="yes" description="“empty” and “empty trash” both do the same thing"/>
			<parameter name="security" code="sec?" type="boolean" optional="yes" description="(obsolete)"/>
		</command>
		<command name="erase" code="fndrfera" description="(NOT AVAILABLE) Erase the specified disk(s)">
			<direct-parameter type="specifier" description="the items to erase"/>
		</command>
		<command name="reveal" code="miscmvis" description="Bring the specified object(s) into view">
			<direct-parameter type="specifier" description="the object to be made visible"/>
		</command>
		<command name="update" code="fndrfupd" description="Update the display of the specified object(s) to match their on-disk representation">
			<direct-parameter type="specifier" description="the item to update"/>
			<parameter name="necessity" code="nec?" type="boolean" optional="yes" description="only update if necessary (i.e. a finder window is open). default is false"/>
			<parameter name="registering applications" code="reg?" type="boolean" optional="yes" description="register applications. default is true"/>
		</command>
		<class name="item" code="cobj" description="An item" plural="items">
			<property name="name" code="pnam" type="text" description="the name of the item"/>
			<property name="displayed name" code="dnam" type="text" access="r" description="the user-visible name of the item"/>
			<property name="name extension" code="nmxt" type="text" description="the name extension of the item (such as “txt”)"/>
			<property name="extension hidden" code="hidx" type="boolean" description="Is the item's extension hidden from the user?"/>
			<property name="index" code="pidx" type="integer" access="r" description="the index in the front-to-back ordering within its container"/>
			<property name="container" code="ctnr" type="specifier" access="r" description="the container of the item"/>
			<property name="disk" code="cdis" type="specifier" access="r" description="the disk on which the item is stored"/>
			<property name="position" code="posn" type="point" description="the position of the item within its parent window (can only be set for an item in a window viewed as icons or buttons)"/>
			<property name="desktop position" code="dpos" type="point" description="the position of the item on the desktop"/>
			<property name="bounds" code="pbnd" type="rectangle" description="the bounding rectangle of the item (can only be set for an item in a window viewed as icons or buttons)"/>
			<property name="label index" code="labi" type="integer" description="the label of the item"/>
			<property name="locked" code="aslk" type="boolean" description="Is the file locked?"/>
			<property name="kind" code="kind" type="text" access="r" description="the kind of the item"/>
			<property name="description" code="dscr" type="text" access="r" description="a description of the item"/>
			<property name="comment" code="comt" type="text" description="the comment of the item, displayed in the “Get Info” window"/>
			<property name="size" code="ptsz" type="double integer" access="r" description="the logical size of the item"/>
			<property name="physical size" code="phys" type="double integer" access="r" description="the actual space used by the item on disk"/>
			<property name="creation date" code="ascd" type="date" access="r" description="the date on which the item was created"/>
			<property name="modification date" code="asmo" type="date" description="the date on which the item was last modified"/>
			<property name="icon" code="iimg" type="icon family" description="the icon bitmap of the item"/>
			<property name="URL" code="pURL" type="text" access="r" description="the URL of the item"/>
			<property name="owner" code="sown" type="text" description="the user that owns the container"/>
			<property name="group" code="sgrp" type="text" description="the user or group that has special access to the container"/>
			<property name="owner privileges" code="ownr" type="priv"/>
			<property name="group privileges" code="gppr" type="priv"/>
			<property name="everyones privileges" code="gstp" type="priv"/>
			<property name="information window" code="iwnd" type="specifier" access="r" description="the information window for the item"/>
			<property name="properties" code="pALL" type="record" description="every property of an item"/>
			<property name="class" code="pcls" type="type" access="r" description="the class of the item"/>
		</class>
		<enumeration name="priv" code="priv">
			<enumerator name="read only" code="read"/>
			<enumerator name="read write" code="rdwr"/>
			<enumerator name="write only" code="writ"/>
			<enumerator name="none" code="none"/>
		</enumeration>
	</suite>

	<suite name="Containers and folders" code="fndr" description="Classes that can contain other file system items">
		<class name="container" code="ctnr" description="An item that contains other items" inherits="item" plural="containers">
			<element type="item"/>
			<element type="container"/>
			<element type="folder"/>
			<element type="file"/>
			<element type="alias file"/>
			<element type="application file"/>
			<element type="document file"/>
			<element type="internet location file"/>
			<element type="clipping"/>
			<element type="package"/>
			<property name="entire contents" code="ects" type="specifier" access="r" description="the entire contents of the container, including the contents of its children"/>
			<property name="expandable" code="pexa" type="boolean" access="r" description="(NOT AVAILABLE YET) Is the container capable of being expanded as an outline?"/>
			<property name="expanded" code="pexp" type="boolean" description="(NOT AVAILABLE YET) Is the container opened as an outline? (can only be set for containers viewed as lists)"/>
			<property name="completely expanded" code="pexc" type="boolean" description="(NOT AVAILABLE YET) Are the container and all of its children opened as outlines? (can only be set for containers viewed as lists)"/>
			<property name="container window" code="cwnd" type="specifier" access="r" description="the container window for this folder"/>
		</class>
		<class name="computer-object" code="ccmp" description="the Computer location (as in Go > Computer)" inherits="item"/>
		<class name="disk" code="cdis" description="A disk" inherits="container" plural="disks">
			<element type="item"/>
			<element type="container"/>
			<element type="folder"/>
			<element type="file"/>
			<element type="alias file"/>
			<element type="application file"/>
			<element type="document file"/>
			<element type="internet location file"/>
			<element type="clipping"/>
			<element type="package"/>
			<property name="id" code="ID  " type="integer" access="r" description="the unique id for this disk (unchanged while disk remains connected and Finder remains running)"/>
			<property name="capacity" code="capa" type="double integer" access="r" description="the total number of bytes (free or used) on the disk"/>
			<property name="free space" code="frsp" type="double integer" access="r" description="the number of free bytes left on the disk"/>
			<property name="ejectable" code="isej" type="boolean" access="r" description="Can the media be ejected (floppies, CDs, and so on)?"/>
			<property name="local volume" code="isrv" type="boolean" access="r" description="Is the media a local volume (as opposed to a file server)?"/>
			<property name="startup" code="istd" type="boolean" access="r" description="Is this disk the boot disk?"/>
			<property name="format" code="dfmt" type="edfm" access="r" description="the filesystem format of this disk"/>
			<property name="journaling enabled" code="Jrnl" type="boolean" access="r" description="Does this disk do file system journaling?"/>
			<property name="ignore privileges" code="igpr" type="boolean" description="Ignore permissions on this disk?"/>
		</class>
		<class name="folder" code="cfol" description="A folder" inherits="container" plural="folders">
			<element type="item"/>
			<element type="container"/>
			<element type="folder"/>
			<element type="file"/>
			<element type="alias file"/>
			<element type="application file"/>
			<element type="document file"/>
			<element type="internet location file"/>
			<element type="clipping"/>
			<element type="package"/>
		</class>
		<class name="desktop-object" code="cdsk" description="Desktop-object is the class of the “desktop” object" inherits="container">
			<element type="item"/>
			<element type="container"/>
			<element type="disk"/>
			<element type="folder"/>
			<element type="file"/>
			<element type="alias file"/>
			<element type="application file"/>
			<element type="document file"/>
			<element type="internet location file"/>
			<element type="clipping"/>
			<element type="package"/>
		</class>
		<class name="trash-object" code="ctrs" description="Trash-object is the class of the “trash” object" inherits="container">
			<element type="item"/>
			<element type="container"/>
			<element type="folder"/>
			<element type="file"/>
			<element type="alias file"/>
			<element type="application file"/>
			<element type="document file"/>
			<element type="internet location file"/>
			<element type="clipping"/>
			<element type="package"/>
			<property name="warns before emptying" code="warn" type="boolean" description="Display a dialog when emptying the trash?"/>
		</class>
		<enumeration name="edfm" code="edfm">
			<enumerator name="Mac OS format" code="dfhf"/>
			<enumerator name="Mac OS Extended format" code="dfh+"/>
			<enumerator name="UFS format" code="dfuf"/>
			<enumerator name="NFS format" code="dfnf"/>
			<enumerator name="audio format" code="dfau"/>
			<enumerator name="ProDOS format" code="dfpr"/>
			<enumerator name="MSDOS format" code="dfms"/>
			<enumerator name="NTFS format" code="dfnt"/>
			<enumerator name="ISO 9660 format" code="df96"/>
			<enumerator name="High Sierra format" code="dfhs"/>
			<enumerator name="QuickTake format" code="dfqt"/>
			<enumerator name="Apple Photo format" code="dfph"/>
			<enumerator name="AppleShare format" code="dfas"/>
			<enumerator name="UDF format" code="dfud"/>
			<enumerator name="WebDAV format" code="dfwd"/>
			<enumerator name="FTP format" code="dfft"/>
			<enumerator name="Packet written UDF format" code="dfpu"/>
			<enumerator name="Xsan format" code="dfac"/>
			<enumerator name="APFS format" code="dfap"/>
			<enumerator name="ExFAT format" code="dfxf"/>
			<enumerator name="SMB format" code="dfsm"/>
			<enumerator name="unknown format" code="df??"/>
		</enumeration>
	</suite>

	<suite name="Files" code="fndr" description="Classes representing files">
		<class name="file" code="file" description="A file" inherits="item" plural="files">
			<property name="file type" code="asty" type="type" description="the OSType identifying the type of data contained in the item"/>
			<property name="creator type" code="fcrt" type="type" description="the OSType identifying the application that created the item"/>
			<property name="stationery" code="pspd" type="boolean" description="Is the file a stationery pad?"/>
			<property name="product version" code="ver2" type="text" access="r" description="the version of the product (visible at the top of the “Get Info” window)"/>
			<property name="version" code="vers" type="text" access="r" description="the version of the file (visible at the bottom of the “Get Info” window)"/>
		</class>
		<class name="alias file" code="alia" description="An alias file (created with “Make Alias”)" inherits="file" plural="alias files">
			<property name="original item" code="orig" type="specifier" description="the original item pointed to by the alias"/>
		</class>
		<class name="application file" code="appf" description="An application's file on disk" inherits="file" plural="application files">
			<property name="id" code="ID  " type="text" access="r" description="the bundle identifier or creator type of the application"/>
			<property name="suggested size" code="sprt" type="integer" access="r" description="(AVAILABLE IN 10.1 TO 10.4) the memory size with which the developer recommends the application be launched"/>
			<property name="minimum size" code="mprt" type="integer" description="(AVAILABLE IN 10.1 TO 10.4) the smallest memory size with which the application can be launched"/>
			<property name="preferred size" code="appt" type="integer" description="(AVAILABLE IN 10.1 TO 10.4) the memory size with which the application will be launched"/>
			<property name="accepts high level events" code="isab" type="boolean" access="r" description="Is the application high-level event aware? (OBSOLETE: always returns true)"/>
			<property name="has scripting terminology" code="hscr" type="boolean" access="r" description="Does the process have a scripting terminology, i.e., can it be scripted?"/>
			<property name="opens in Classic" code="Clsc" type="boolean" description="(AVAILABLE IN 10.1 TO 10.4) Should the application launch in the Classic environment?"/>
		</class>
		<class name="document file" code="docf" description="A document file" inherits="file" plural="document files"/>
		<class name="internet location file" code="inlf" description="A file containing an internet location" inherits="file" plural="internet location files">
			<property name="location" code="iloc" type="text" access="r" description="the internet location"/>
		</class>
		<class name="clipping" code="clpf" description="A clipping" inherits="file" plural="clippings">
			<property name="clipping window" code="lwnd" type="specifier" access="r" description="(NOT AVAILABLE YET) the clipping window for this clipping"/>
		</class>
		<class name="package" code="pack" description="A package" inherits="item" plural="packages"/>
	</suite>

	<suite name="Window classes" code="fndr" description="Classes representing windows">
		<class name="window" code="cwin" description="A window" plural="windows">
			<property name="id" code="ID  " type="integer" access="r" description="the unique id for this window"/>
			<property name="position" code="posn" type="point" description="the upper left position of the window"/>
			<property name="bounds" code="pbnd" type="rectangle" description="the boundary rectangle for the window"/>
			<property name="titled" code="ptit" type="boolean" access="r" description="Does the window have a title bar?"/>
			<property name="name" code="pnam" type="text" access="r" description="the name of the window"/>
			<property name="index" code="pidx" type="integer" description="the number of the window in the front-to-back layer ordering"/>
			<property name="closeable" code="hclb" type="boolean" access="r" description="Does the window have a close box?"/>
			<property name="floating" code="isfl" type="boolean" access="r" description="Does the window have a title bar?"/>
			<property name="modal" code="pmod" type="boolean" access="r" description="Is the window modal?"/>
			<property name="resizable" code="prsz" type="boolean" access="r" description="Is the window resizable?"/>
			<property name="zoomable" code="iszm" type="boolean" access="r" description="Is the window zoomable?"/>
			<property name="zoomed" code="pzum" type="boolean" description="Is the window zoomed?"/>
			<property name="visible" code="pvis" type="boolean" access="r" description="Is the window visible (always true for open Finder windows)?"/>
			<property name="collapsed" code="wshd" type="boolean" description="Is the window collapsed"/>
			<property name="properties" code="pALL" type="record" description="every property of a window"/>
		</class>
		<class name="Finder window" code="brow" description="A file viewer window" inherits="window" plural="Finder windows">
			<property name="target" code="fvtg" type="specifier" description="the container at which this file viewer is targeted"/>
			<property name="current view" code="pvew" type="ecvw" description="the current view for the container window"/>
			<property name="icon view options" code="icop" type="icon view options" access="r" description="the icon view options for the container window"/>
			<property name="list view options" code="lvop" type="list view options" access="r" description="the list view options for the container window"/>
			<property name="column view options" code="cvop" type="column view options" access="r" description="the column view options for the container window"/>
			<property name="toolbar visible" code="tbvi" type="boolean" description="Is the window's toolbar visible?"/>
			<property name="statusbar visible" code="stvi" type="boolean" description="Is the window's status bar visible?"/>
			<property name="pathbar visible" code="pbvi" type="boolean" description="Is the window's path bar visible?"/>
			<property name="sidebar width" code="sbwi" type="integer" description="the width of the sidebar for the container window"/>
		</class>
		<class name="desktop window" code="dktw" description="the desktop window" inherits="Finder window"/>
		<class name="information window" code="iwnd" description="An inspector window (opened by “Show Info”)" inherits="window">
			<property name="item" code="cobj" type="specifier" access="r" description="the item from which this window was opened"/>
			<property name="current panel" code="panl" type="ipnl" description="the current panel in the information window"/>
		</class>
		<class name="preferences window" code="pwnd" description="The Finder Preferences window" inherits="window">
			<property name="current panel" code="panl" type="pple" description="The current panel in the Finder preferences window"/>
		</class>
		<class name="clipping window" code="lwnd" description="The window containing a clipping" inherits="window" plural="clipping windows"/>
		<enumeration name="ipnl" code="ipnl">
			<enumerator name="General Information panel" code="gpnl"/>
			<enumerator name="Sharing panel" code="spnl"/>
			<enumerator name="Memory panel" code="mpnl"/>
			<enumerator name="Preview panel" code="vpnl"/>
			<enumerator name="Application panel" code="apnl"/>
			<enumerator name="Languages panel" code="pklg"/>
			<enumerator name="Plugins panel" code="pkpg"/>
			<enumerator name="Name &amp; Extension panel" code="npnl"/>
			<enumerator name="Comments panel" code="cpnl"/>
			<enumerator name="Content Index panel" code="cinl"/>
			<enumerator name="Burning panel" code="bpnl"/>
			<enumerator name="More Info panel" code="minl"/>
			<enumerator name="Simple Header panel" code="shnl"/>
		</enumeration>
		<enumeration name="pple" code="pple">
			<enumerator name="General Preferences panel" code="pgnp"/>
			<enumerator name="Label Preferences panel" code="plbp"/>
			<enumerator name="Sidebar Preferences panel" code="psid"/>
			<enumerator name="Advanced Preferences panel" code="padv"/>
		</enumeration>
		<enumeration name="ecvw" code="ecvw">
			<enumerator name="icon view" code="icnv"/>
			<enumerator name="list view" code="lsvw"/>
			<enumerator name="column view" code="clvw"/>
			<enumerator name="group view" code="flvw"/>
			<enumerator name="flow view" code="flvw"/>
		</enumeration>
	</suite>

	<suite name="Legacy suite" code="fleg" description="Operations formerly handled by the Finder, but now automatically delegated to other applications">
		<command name="restart" code="fndrrest" description="Restart the computer"/>
		<command name="shut down" code="fndrshut" description="Shut Down the computer"/>
		<command name="sleep" code="fndrslep" description="Put the computer to sleep"/>
		<class-extension extends="application" description="The Finder">
			<property name="desktop picture" code="dpic" type="file" description="the desktop picture of the main monitor"/>
		</class-extension>
		<class name="process" code="prcs" description="A process running on this computer" plural="processes">
			<property name="name" code="pnam" type="text" access="r" description="the name of the process"/>
			<property name="visible" code="pvis" type="boolean" description="Is the process' layer visible?"/>
			<property name="frontmost" code="pisf" type="boolean" description="Is the process the frontmost process?"/>
			<property name="file" code="file" type="specifier" access="r" description="the file from which the process was launched"/>
			<property name="file type" code="asty" type="type" access="r" description="the OSType of the file type of the process"/>
			<property name="creator type" code="fcrt" type="type" access="r" description="the OSType of the creator of the process (the signature)"/>
			<property name="accepts high level events" code="isab" type="boolean" access="r" description="Is the process high-level event aware (accepts open application, open document, print document, and quit)?"/>
			<property name="accepts remote events" code="revt" type="boolean" access="r" description="Does the process accept remote events?"/>
			<property name="has scripting terminology" code="hscr" type="boolean" access="r" description="Does the process have a scripting terminology, i.e., can it be scripted?"/>
			<property name="total partition size" code="appt" type="integer" access="r" description="the size of the partition with which the process was launched"/>
			<property name="partition space used" code="pusd" type="integer" access="r" description="the number of bytes currently used in the process' partition"/>
		</class>
		<class name="application process" code="pcap" description="A process launched from an application file" inherits="process" plural="application processes">
			<property name="application file" code="appf" type="application file" access="r" description="the application file from which this process was launched"/>
		</class>
		<class name="desk accessory process" code="pcda" description="A process launched from a desk accessory file" inherits="process" plural="desk accessory processes">
			<property name="desk accessory file" code="dafi" type="specifier" access="r" description="the desk accessory file from which this process was launched"/>
		</class>
	</suite>

	<suite name="Type Definitions" code="tpdf" description="Definitions of records used in scripting the Finder">
		<class name="preferences" code="cprf" description="The Finder Preferences">
			<property name="window" code="cwin" type="preferences window" access="r" description="the window that would open if Finder preferences was opened"/>
			<property name="icon view options" code="icop" type="icon view options" access="r" description="the default icon view options"/>
			<property name="list view options" code="lvop" type="list view options" access="r" description="the default list view options"/>
			<property name="column view options" code="cvop" type="column view options" access="r" description="the column view options for all windows"/>
			<property name="folders spring open" code="sprg" type="boolean" description="Spring open folders after the specified delay?"/>
			<property name="delay before springing" code="dela" type="real" description="the delay before springing open a container in seconds (from 0.167 to 1.169)"/>
			<property name="desktop shows hard disks" code="pdhd" type="boolean" description="Hard disks appear on the desktop?"/>
			<property name="desktop shows external hard disks" code="pehd" type="boolean" description="External hard disks appear on the desktop?"/>
			<property name="desktop shows removable media" code="pdrm" type="boolean" description="CDs, DVDs, and iPods appear on the desktop?"/>
			<property name="desktop shows connected servers" code="pdsv" type="boolean" description="Connected servers appear on the desktop?"/>
			<property name="new window target" code="pnwt" type="specifier" description="target location for a newly-opened Finder window"/>
			<property name="folders open in new windows" code="ponw" type="boolean" description="Folders open into new windows?"/>
			<property name="folders open in new tabs" code="pont" type="boolean" description="Folders open into new tabs?"/>
			<property name="new windows open in column view" code="pocv" type="boolean" description="Open new windows in column view?"/>
			<property name="all name extensions showing" code="psnx" type="boolean" description="Show name extensions, even for items whose “extension hidden” is true?"/>
		</class>
		<class name="label" code="clbl" description="(NOT AVAILABLE YET) A Finder label (name and color)">
			<property name="name" code="pnam" type="text" description="the name associated with the label"/>
			<property name="index" code="pidx" type="integer" description="the index in the front-to-back ordering within its container"/>
			<property name="color" code="colr" type="RGB color" description="the color associated with the label"/>
		</class>
		<class name="icon family" code="ifam" description="(NOT AVAILABLE YET) A family of icons">
			<property name="large monochrome icon and mask" code="ICN#" type="ICN#" access="r" description="the large black-and-white icon and the mask for large icons"/>
			<property name="large 8 bit mask" code="l8mk" type="l8mk" access="r" description="the large 8-bit mask for large 32-bit icons"/>
			<property name="large 32 bit icon" code="il32" type="il32" access="r" description="the large 32-bit color icon"/>
			<property name="large 8 bit icon" code="icl8" type="icl8" access="r" description="the large 8-bit color icon"/>
			<property name="large 4 bit icon" code="icl4" type="icl4" access="r" description="the large 4-bit color icon"/>
			<property name="small monochrome icon and mask" code="ics#" type="ics#" access="r" description="the small black-and-white icon and the mask for small icons"/>
			<property name="small 8 bit mask" code="ics8" type="s8mk" access="r" description="the small 8-bit mask for small 32-bit icons"/>
			<property name="small 32 bit icon" code="is32" type="is32" access="r" description="the small 32-bit color icon"/>
			<property name="small 8 bit icon" code="ics8" type="ics8" access="r" description="the small 8-bit color icon"/>
			<property name="small 4 bit icon" code="ics4" type="ics4" access="r" description="the small 4-bit color icon"/>
		</class>
		<class name="icon view options" code="icop" description="the icon view options">
			<property name="arrangement" code="iarr" type="earr" description="the property by which to keep icons arranged"/>
			<property name="icon size" code="lvis" type="integer" description="the size of icons displayed in the icon view"/>
			<property name="shows item info" code="mnfo" type="boolean" description="additional info about an item displayed in icon view"/>
			<property name="shows icon preview" code="prvw" type="boolean" description="displays a preview of the item in icon view"/>
			<property name="text size" code="fsiz" type="integer" description="the size of the text displayed in the icon view"/>
			<property name="label position" code="lpos" type="epos" description="the location of the label in reference to the icon"/>
			<property name="background picture" code="ibkg" type="file" description="the background picture of the icon view"/>
			<property name="background color" code="colr" type="RGB color" description="the background color of the icon view"/>
		</class>
		<class name="column view options" code="cvop" description="the column view options">
			<property name="text size" code="fsiz" type="integer" description="the size of the text displayed in the column view"/>
			<property name="shows icon" code="shic" type="boolean" description="displays an icon next to the label in column view"/>
			<property name="shows icon preview" code="prvw" type="boolean" description="displays a preview of the item in column view"/>
			<property name="shows preview column" code="shpr" type="boolean" description="displays the preview column in column view"/>
			<property name="discloses preview pane" code="dspr" type="boolean" description="discloses the preview pane of the preview column in column view"/>
		</class>
		<class name="list view options" code="lvop" description="the list view options">
			<element type="column"/>
			<property name="calculates folder sizes" code="sfsz" type="boolean" description="Are folder sizes calculated and displayed in the window?"/>
			<property name="shows icon preview" code="prvw" type="boolean" description="displays a preview of the item in list view"/>
			<property name="icon size" code="lvis" type="lvic" description="the size of icons displayed in the list view"/>
			<property name="text size" code="fsiz" type="integer" description="the size of the text displayed in the list view"/>
			<property name="sort column" code="srtc" type="column" description="the column that the list view is sorted on"/>
			<property name="uses relative dates" code="urdt" type="boolean" description="Are relative dates (e.g., today, yesterday) shown in the list view?"/>
		</class>
		<class name="column" code="lvcl" description="a column of a list view" plural="columns">
			<property name="index" code="pidx" type="integer" description="the index in the front-to-back ordering within its container"/>
			<property name="name" code="pnam" type="elsv" access="r" description="the column name"/>
			<property name="sort direction" code="sord" type="sodr" description="The direction in which the window is sorted"/>
			<property name="width" code="clwd" type="integer" description="the width of this column"/>
			<property name="minimum width" code="clwn" type="integer" access="r" description="the minimum allowed width of this column"/>
			<property name="maximum width" code="clwm" type="integer" access="r" description="the maximum allowed width of this column"/>
			<property name="visible" code="pvis" type="boolean" description="is this column visible"/>
		</class>
		<class name="alias list" code="alst" description="A list of aliases. Use ‘as alias list’ when a list of aliases is needed (instead of a list of file system item references)."/>
		<enumeration name="earr" code="earr">
			<enumerator name="not arranged" code="narr"/>
			<enumerator name="snap to grid" code="grda"/>
			<enumerator name="arranged by name" code="nama"/>
			<enumerator name="arranged by modification date" code="mdta"/>
			<enumerator name="arranged by creation date" code="cdta"/>
			<enumerator name="arranged by size" code="siza"/>
			<enumerator name="arranged by kind" code="kina"/>
			<enumerator name="arranged by label" code="laba"/>
		</enumeration>
		<enumeration name="epos" code="epos">
			<enumerator name="right" code="lrgt"/>
			<enumerator name="bottom" code="lbot"/>
		</enumeration>
		<enumeration name="sodr" code="sodr">
			<enumerator name="normal" code="snrm"/>
			<enumerator name="reversed" code="srvs"/>
		</enumeration>
		<enumeration name="elsv" code="elsv">
			<enumerator name="name column" code="elsn"/>
			<enumerator name="modification date column" code="elsm"/>
			<enumerator name="creation date column" code="elsc"/>
			<enumerator name="size column" code="elss"/>
			<enumerator name="kind column" code="elsk"/>
			<enumerator name="label column" code="elsl"/>
			<enumerator name="version column" code="elsv"/>
			<enumerator name="comment column" code="elsC"/>
		</enumeration>
		<enumeration name="lvic" code="lvic">
			<enumerator name="small icon" code="smic"/>
			<enumerator name="large icon" code="lgic"/>
		</enumeration>
	</suite>

	<suite name="Enumerations" code="tpnm" description="Enumerations for the Finder" hidden="yes">
		<enumeration name="isiz" code="isiz" hidden="yes">
			<enumerator name="mini" code="miic"/>
			<enumerator name="small" code="smic"/>
			<enumerator name="large" code="lgic"/>
		</enumeration>
		<enumeration name="sort" code="sort" hidden="yes">
			<enumerator name="name" code="pnam"/>
			<enumerator name="modification date" code="asmo"/>
			<enumerator name="creation date" code="ascd"/>
			<enumerator name="size" code="phys"/>
			<enumerator name="kind" code="kind"/>
			<enumerator name="label index" code="labi"/>
			<enumerator name="comment" code="comt"/>
			<enumerator name="version" code="vers"/>
		</enumeration>
		<value-type name="unsigned integer" code="magn"/>
		<value-type name="double integer" code="comp"/>
		<value-type name="RGB color" code="cRGB"/>
		<value-type name="list" code="list"/>
		<value-type name="property" code="prop"/>
		<value-type name="ICN#" code="ICN#"/>
		<value-type name="icl4" code="icl4"/>
		<value-type name="icl8" code="icl8"/>
		<value-type name="ics#" code="ics#"/>
		<value-type name="ics4" code="ics4"/>
		<value-type name="ics8" code="ics8"/>
		<value-type name="il32" code="il32"/>
		<value-type name="is32" code="is32"/>
		<value-type name="l8mk" code="l8mk"/>
		<value-type name="s8mk" code="s8mk"/>
	</suite>

</dictionary>
