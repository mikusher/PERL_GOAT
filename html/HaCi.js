var origNetaddress		= '';
var maxTmplPositions	= 0;
var ipv6							= 0;
var statID						= 0;
var objDrag						= null;
var mouseX						= 0;
var mouseY						= 0;
var offX							= 0;
var offY							= 0;
var maxSubnetSize			= 8;

IE	= document.all&&!window.opera;
DOM	= document.getElementById&&!IE;

function init(){
	document.onmousemove	= doDrag;
	document.onmouseup		= stopDrag;
}

function updateDefSubnetCidr () {
	var rootID	= document.getElementById('rootID').value;
	var ipv6		= rootID2Ver[rootID];

	if (document.getElementById('conf_maxSubnetSize'))
		maxSubnetSize	= parseInt(document.getElementById('conf_maxSubnetSize').value);

	var cidr	= parseInt(document.getElementById('cidr').value);

	var subnetSizeSel					= document.getElementById('defSubnetSize');
	var subnetSizeLength  		= subnetSizeSel.length;
	var defSubnetSizeSelIndex	= subnetSizeSel.selectedIndex;
	var defSubnetSizeSelVal		= subnetSizeSel[defSubnetSizeSelIndex].value;

	for (i = 1; i < subnetSizeLength; i++) {
		subnetSizeSel[1]	= null;
	}

	if (isNaN(cidr))
		return;

	var startVal	= (cidr + 1);
	var endVal		= (startVal + (maxSubnetSize - 1));
	if (ipv6 == 1) {
		if (cidr >= 128)
			return
		if (endVal > 128)
			endVal	= 128
	} else {
		if (cidr >= 32)
			return
		if (endVal > 32)
			endVal	= 32
	}

	var u				= 1;
	for (i = startVal; i <= endVal; i++) {
		newEntry					= new Option(i, i, false, false);
		subnetSizeSel[u]	= newEntry;
		if (newEntry.value == defSubnetSizeSelVal)
			subnetSizeSel.selectedIndex	= u;
		u++;
	}
}
	
function checkIfIPv6 (rootID, source) {
	var rootID	= document.getElementById('rootID').value;
	ipv6				= rootID2Ver[rootID];

	if (source == 'TREE') {
		var jumpToTB	= document.getElementById('jumpTo');
		if (ipv6 == 1) {
			jumpToTB.size				= 39;
			jumpToTB.maxlength	= 39;
		} else {
			jumpToTB.size				= 18;
			jumpToTB.maxlength	= 18;
		}
	}
	else if (source == 'ADDNET') {
		var netmaskBlock	= document.getElementsByName("netmaskBlock")[0];

		updateDefSubnetCidr();

		if (ipv6 == 1) {
			if (netmaskBlock) {
				netmaskBlock.style.display	= 'none';
			} else {
				document.getElementById('netmask').disabled	= true;
			}
			document.getElementsByName('netaddress')[0].size			= 43;
			document.getElementsByName('netaddress')[0].maxLength	= 43;
			document.getElementsByName('cidr')[0].size			= 3;
			document.getElementsByName('cidr')[0].maxLength	= 3;
		} else {
			if (netmaskBlock) {
				netmaskBlock.style.display	= 'table-row';
			} else {
				document.getElementById('netmask').disabled	= false;
			}
			document.getElementsByName('netaddress')[0].size			= 18;
			document.getElementsByName('netaddress')[0].maxLength	= 18;
			document.getElementsByName('cidr')[0].size			= 2;
			document.getElementsByName('cidr')[0].maxLength	= 2;
		}
	}
}

function setFocus (formElement) {
	var element	= document.getElementById(formElement)
	if (element) {
		element.focus();
	}
}

function setCIDR (netmask, target_cidr, target_netaddress, target_netmask) {
	if (ipv6 == 1) {
		document.getElementById(target_cidr).value	= netmask; // netmask = cidr if ipv6

		updateDefSubnetCidr();

		return;
	}
	var splits	= netmask.split(".");
	var cidr				= 0;
	var newNetmask	= '';
	
	for (var i = 0; i < 4;i++) {
		if (splits[i] > 255) {
			splits[i]	= 255;
		}
		if (splits[i] < 0) {
			splits[i]	= 0;
		}
		if (newNetmask != '')
			newNetmask	= newNetmask + '.';
		newNetmask	= newNetmask + splits[i];
	}
	if (netmask != newNetmask)
		document.getElementById(target_netmask).value	= newNetmask;

	netmask			= newNetmask;
	var splits	= netmask.split(".");

	for (var i = (splits.length - 1); i >= 0; --i) {
		var a	= Math.log(256 - splits[i])/Math.log(2);
		cidr = (cidr + a);
	}
	cidr	= 32 - cidr;
	document.getElementById(target_cidr).value				= cidr;
	document.getElementById(target_netaddress).value	= getNetaddress(document.getElementById(target_netaddress).value, netmask);

	updateDefSubnetCidr();

	return cidr;
}

function setNetmask (cidr, target_netmask, target_netaddress, target_cidr) {
	if (cidr < 0) {
		cidr	= 0;
		document.getElementById(target_cidr).value	= cidr;
	}

	if (ipv6 == 1) {
		if (cidr > 128) {
			cidr	= 128;
			document.getElementById(target_cidr).value	= cidr;
		}
		document.getElementById(target_netaddress).value	= getNetaddress(document.getElementById(target_netaddress).value, cidr);

		updateDefSubnetCidr();

		return;
	}
	var netmask	= '';
	if (cidr > 32) {
		cidr	= 32;
		document.getElementById(target_cidr).value	= cidr;
	}

	for (var i=0; i<4; i++) {
		var netmaskt	= 0;
		if (cidr > 8) {
			netmaskt	= 8;
			cidr			= cidr - 8;
		} else {
			netmaskt	= cidr;
			cidr			= 0;
		}
		netmaskt	= 256 - Math.pow(2, (8 - netmaskt));
		if (netmask != '')
			netmask	= netmask + '.';
		netmask	= netmask + netmaskt;
	}
	document.getElementById(target_netmask).value			= netmask;
	document.getElementById(target_netaddress).value	= getNetaddress(document.getElementById(target_netaddress).value, netmask);

	updateDefSubnetCidr();

	return netmask;
}

function setnetmask_cidr (network, target_netmask, target_cidr, target_netaddress) {
	var splits	= network.split('/');
	if (ipv6 == 1) {
		splits[0]	= adjustIPv6(splits[0]);
		if (splits[1]) {
			setCIDR(splits[1], target_cidr);
			document.getElementById(target_netaddress).value	= getNetaddress(splits[0], splits[1], 1);
		} else {
			document.getElementById(target_netaddress).value	= splits[0];
		}
		return;
	}
	var netmask	= '';
	if (splits[1]) {
		netmask	= setNetmask(splits[1], target_netmask, target_netaddress);
		setCIDR(netmask, target_cidr, target_netaddress);
		document.getElementById(target_netaddress).value	= getNetaddress(splits[0], netmask, 1);
	}
}

function pow (x, y) {
	if (y < 0) {
		return x;
	}
	if (y == 0) {
		return int2bigInt(1, 32, 0);
	}
	if (y == 1) {
		return x;
	}

	var z	= dup(x);
	for (var i=2; i<=y; i++) {
		x	= mult(x, z);
	}
	return x;
}

function ipv62Dec (ipv6) {
	var ipSplits	= ipv6.split(':');
	var ipv6Dec		= int2bigInt(0, 128, 0);
	var base			= int2bigInt(65536, 128, 0);
	for (var i=0; i<ipSplits.length; i++) {
		var dec				= parseInt(ipSplits[i], 16);
		var currBase	= dup(base);
		var currPow		= ((ipSplits.length - 1) - i);
		currBase			= pow(currBase, currPow);
		multInt_(currBase, dec);
		if (dec == 0)
			currBase		= int2bigInt(0, 128, 0);
		ipv6Dec				= add(ipv6Dec, currBase);
	}

	return ipv6Dec;
}

function ipv6Dec2ip (ipv6Dec) {
	var base			= int2bigInt(65536, 128, 0);
	var q					= int2bigInt(0, 128, 0);
	var r					= int2bigInt(0, 128, 0);
	var currBase	= dup(base);
	var ipv6			= '';
	var currIPv6Dec;

	var i1				= bigInt2str(mod(ipv6Dec, base), 16);
	ipv6					= i1;
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	var i2				= bigInt2str(mod(currIPv6Dec, base), 16);
	ipv6					= i2 + ':' + ipv6;
	currBase			= pow(base, 2);
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	var i3				= bigInt2str(mod(currIPv6Dec, base), 16);
	ipv6					= i3 + ':' + ipv6;
	currBase			= pow(base, 3);
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	var i4				= bigInt2str(mod(currIPv6Dec, base), 16);
	ipv6					= i4 + ':' + ipv6;
	currBase			= pow(base, 4);
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	var i5				= bigInt2str(mod(currIPv6Dec, base), 16);
	ipv6					= i5 + ':' + ipv6;
	currBase			= pow(base, 5);
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	var i6				= bigInt2str(mod(currIPv6Dec, base), 16);
	ipv6					= i6 + ':' + ipv6;
	currBase			= pow(base, 6);
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	var i7				= bigInt2str(mod(currIPv6Dec, base), 16);
	ipv6					= i7 + ':' + ipv6;
	currBase			= pow(base, 7);
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	var i8				= bigInt2str(mod(currIPv6Dec, base), 16);
	ipv6					= i8 + ':' + ipv6;
	currBase			= pow(base, 8);
	divide_(dup(ipv6Dec), currBase, q, r);
	currIPv6Dec		= dup(q);

	return ipv6;
}

function adjustIPv6 (ipv6) {
	var ipSplits			= ipv6.split(':');
	var ipv6Adjusted	= '';
	for (var i=0; i<ipSplits.length; i++) {
		var split	= ipSplits[i];
		if (split == '') {
			split	= '0';
			if (i > 0 && i<(ipSplits.length - 1)) {
				for (var u=ipSplits.length; u<8; u++) {
					split += ':0';
				}
			}
		}
		if (ipv6Adjusted != '')
			ipv6Adjusted	+= ':';
		ipv6Adjusted		+= split;
	}

	return ipv6Adjusted;
}

function getNetaddress (ipaddress, netmask, overwrite) {
	var splits	= ipaddress.split('/');
	ipaddress		= splits[0];

	if (origNetaddress == '')
		origNetaddress	= ipaddress;
	
	if (overwrite == 1)
		origNetaddress	= ipaddress;
	
	ipaddress	= origNetaddress;

	if (ipv6 == 1) {
		ipaddress				= adjustIPv6(ipaddress);
		var cidr				= netmask;  // if ipv6
		var zero				= int2bigInt(0, 32, 0);
		var two					= int2bigInt(2, 32, 0);
		var netmask			= pow(two, (128 - cidr));
		var ipv6Dec			= ipv62Dec(ipaddress);
		var tooMuch			= mod(ipv6Dec, netmask);
		ipv6Dec					= sub(ipv6Dec, tooMuch);
		var ipv6Address	= ipv6Dec2ip(ipv6Dec);

		return ipv6Address;
	}

	var ipSplits		= ipaddress.split('.');
	var maskSplits	= netmask.split('.');
	var netaddress	= '';

	for (var i=0; i<4; i++) {
		var ips		= 256 - maskSplits[i];
		if (netaddress != '')
			netaddress	+= '.';
		if (ips == 0) {
			netaddress	+= ipSplits[i];
		} else {
			netaddress += ips * Math.floor(ipSplits[i] / ips);
		}
	}
	return netaddress;
}

function dec2ip (dec) {
	return
		dec / Math.pow(256, 3) + '.' +
		dec % Math.pow(256, 3) / Math.pow(256, 2) + '.' +
		dec % Math.pow(256, 2) / 256 + '.' +
		dec % 256
}

function updTmplParamsFromPreview (ID, type, pos) {
	var noCheckPos	= 0;
	if (ID == undefined) {
		noCheckPos	= 1;
		pos		= document.getElementById('position').value;
		if (pos == maxTmplPositions)
			return;

		var IDFull	= document.getElementById('tmplEntryPos2ID_' + pos).value;
		type				= [document.getElementsByName(IDFull)[0].title];
		type				= type * 1;
		ID					= IDFull.split('_')[1];
	}
	document.getElementById('TmplEntryParamDescr').disabled		= '';
	document.getElementById('TmplEntryParamSize').disabled		= 'disabled';
	document.getElementById('TmplEntryParamEntries').disabled	= 'disabled';
	document.getElementById('TmplEntryParamRows').disabled		= 'disabled';
	document.getElementById('TmplEntryParamCols').disabled		= 'disabled';
	document.getElementById('TmplEntryParamDescr').value			= '';
	document.getElementById('TmplEntryParamSize').value				= '';
	document.getElementById('TmplEntryParamEntries').value		= '';
	document.getElementById('TmplEntryParamRows').value				= '';
	document.getElementById('TmplEntryParamCols').value				= '';

	document.getElementById('position').value	= pos;

	if (noCheckPos == 0) 
		chkTmplPosition();

	document.getElementById('TmplEntryType').selectedIndex	= type;
	document.getElementById('tmplEntryID').value						= ID;
	switch (type) {
		case 0:
			document.getElementById('TmplEntryParamDescr').disabled		= 'disabled';
			break;
		case 1:
			document.getElementById('TmplEntryParamDescr').value		= document.getElementById('tmplEntryDescrID_' + ID).value;
			document.getElementById('TmplEntryParamSize').disabled	= '';
			document.getElementById('TmplEntryParamSize').value			= document.getElementById('tmplEntryID_' + ID).size;
			break;
		case 2:
			document.getElementById('TmplEntryParamDescr').value		= document.getElementById('tmplEntryDescrID_' + ID).value;
			document.getElementById('TmplEntryParamRows').disabled	= '';
			document.getElementById('TmplEntryParamRows').value			= document.getElementById('tmplEntryID_' + ID).rows;
			document.getElementById('TmplEntryParamCols').disabled	= '';
			document.getElementById('TmplEntryParamCols').value			= document.getElementById('tmplEntryID_' + ID).cols;
			break;
		case 3:
			var optionStr	= '';
			for (i = 0; i < document.getElementsByTagName("option").length; i++) {
				var tagTitle	= document.getElementsByTagName("option")[i].title;
				if (tagTitle == 'tmplEntryID_' + ID) {
					var tagValue	= document.getElementsByTagName("option")[i].value;
					if (optionStr != '')
						optionStr	+= ';';
					optionStr	+= tagValue;
				}
			}
			document.getElementById('TmplEntryParamDescr').value			= document.getElementById('tmplEntryDescrID_' + ID).value;
			document.getElementById('TmplEntryParamEntries').disabled	= '';
			document.getElementById('TmplEntryParamEntries').value		= optionStr;
			break;
		case 4:
			document.getElementById('TmplEntryParamDescr').value		= document.getElementById('tmplEntryDescrID_' + ID).value;
			break;
	}
}

function updTmplParams () {
	document.getElementById('TmplEntryParamDescr').disabled		= '';
	document.getElementById('TmplEntryParamSize').disabled		= 'disabled';
	document.getElementById('TmplEntryParamEntries').disabled	= 'disabled';
	document.getElementById('TmplEntryParamRows').disabled		= 'disabled';
	document.getElementById('TmplEntryParamCols').disabled		= 'disabled';
	var entryType	= document.getElementById('TmplEntryType');
	switch (entryType.value) {
	  case "0":
			document.getElementById('TmplEntryParamDescr').disabled	= 'disabled';
			break;
	  case "1":
			document.getElementById('TmplEntryParamSize').disabled	= '';
			break;
	  case "2":
			document.getElementById('TmplEntryParamRows').disabled	= '';
			document.getElementById('TmplEntryParamCols').disabled	= '';
			break;
	  case "3":
			document.getElementById('TmplEntryParamEntries').disabled	= '';
			break;
	}
}

function setACLs (id, acl) {
	switch (acl) {
		case "r":
			if (document.getElementById('accGroup_r_' + id).checked == false) {
				document.getElementById('accGroup_w_' + id).checked	= false;
			}
			break;
		case "w":
			if (document.getElementById('accGroup_w_' + id).checked == true) {
				document.getElementById('accGroup_r_' + id).checked	= true;
			}
			break;
	}
}

function chkTmplPosition (max) {
	if (max != undefined) {
		maxTmplPositions	= max;
	} else {
		max = maxTmplPositions;
	}
	var pos	= document.getElementById('position').value;
	if (pos >= max) {
		document.getElementById('submitEditTmplEntry').className		= 'boxButtonDisabled';
		document.getElementById('submitEditTmplEntry').disabled			= 1;
		document.getElementById('submitDeleteTmplEntry').className	= 'boxButtonDisabled';
		document.getElementById('submitDeleteTmplEntry').disabled		= 1;
	} else {
		document.getElementById('submitEditTmplEntry').className		= 'boxButton';
		document.getElementById('submitEditTmplEntry').disabled			= 0;
		document.getElementById('submitDeleteTmplEntry').className	= 'boxButton';
		document.getElementById('submitDeleteTmplEntry').disabled		= 0;
	}
}

function implButton (id, name, value, formName, buttonID, type) {
	if (document.getElementById(buttonID)) {
		if (document.getElementById(buttonID).disabled == 1) {
			return;
		}
	}
	var el	= document.getElementById(id);
	if (el != undefined) {
		el.name		= name;
		el.value	= value;
		if (type == 'submit') {
			document[formName].submit();
		}
	}
}

function callAjaxFunction (funcName, paramIDs, target) {
	var attrStr	= '';
	if (target == undefined)
		target	= 'statusContent';
	
	for (i=0; i<paramIDs.length; i++) {
		var param	= paramIDs[i];
		var elem	= document.getElementById(param);
		if (elem == undefined) continue;
		
		var value	= undefined;
		if (elem.nodeName == 'INPUT') {
			for (u=0; u<elem.attributes.length; u++) {
				if (elem.attributes[u].nodeName == 'type') {
					if (elem.attributes[u].nodeValue == 'text') {
						value	= elem.value;
						break;
					} else if (elem.attributes[u].nodeValue == 'checkbox') {
						value	= elem.checked;
						break;
					}
				}
			}
		}
		if (attrStr != '')
			attrStr	+= ',';
		attrStr += "'args__" + value + "'";
	}
	
	eval(funcName + "([" + attrStr + ", 'NO_CACHE'], ['" + target + "'], 'POST');");
	setTimeout("showStatus(1)", 1000)
}

function showStatus(fresh) {
	if (fresh == undefined)
		fresh	= 0;

	eval("mkShowStatus(['args__" + fresh + "'], [procStatus])");
}

function procStatus(status, data) {
	var sc	= document.getElementById('statusContent');
	if (data == undefined)
		data	= '';

	if (status == 'FINISH') {
		sc.innerHTML	= '';
	} else {
		sc.innerHTML	= data;
		setTimeout("showStatus()", 500)
	}
}

function refresh () {
	location.reload();
}

pjx.prototype.pjxInitialized = function(el){
	if (document.getElementById('statusType')) {
		document.getElementById('statusType').style.color						= "#FF0000";
		document.getElementById('statusType').style.textDecoration  = "blink";
	}
}

pjx.prototype.pjxCompleted = function(el){
	if (document.getElementById('statusType')) {
		document.getElementById('statusType').style.color						= "#000000";
		document.getElementById('statusType').style.textDecoration  = "none";
	}
}

function a (func, netID, rootID, networkDec, fillNet) {
	if (func == 'editNet') {
		document.getElementById('func').name	= 'editNet';
		document.getElementById('func').value	= 1;
	}
	else if (func == 'delNet') {
		document.getElementById('func').name	= 'delNet';
		document.getElementById('func').value	= 1;
	}
	else {
		document.getElementById('func').value	= func;
	}
	document.getElementById('netID').value			= netID;
	document.getElementById('rootID').value			= rootID;
	document.getElementById('networkDec').value	= networkDec;
	document.getElementById('fillNet').value		= fillNet;
	document.treeMenu.submit();
}

function submitOnEnter (ev, buttonID) {
	if (ev.keyCode == 13) {
		document.getElementById(buttonID).onclick();
	}
}

function setPluginID(ID) {
	document.getElementById('pluginID').value	= ID;
}

function showDescrHelper() {
	var elem						= document.getElementById('descrHelper');
	elem.style.display	= 'block';
}

function hideDescrHelper() {
	var elem						= document.getElementById('descrHelper');
	elem.style.display	= 'none';
}

function showWarnl() {
	var elem						= document.getElementById('warnl');
	elem.style.display	= 'block';
}

function hideWarnl() {
	var elem						= document.getElementById('warnl');
	elem.style.display	= 'none';
}

function showStatusHelper() {
	var elem						= document.getElementById('statusHelper');
	elem.style.display	= 'block';
}

function hideStatusHelper() {
	var elem						= document.getElementById('statusHelper');
	elem.style.display	= 'none';
}

function insertPluginVar(target, str) {
	var target	= document.getElementById(target);
	var text		= target.value;
	text				+= str;

	target.value	= text;
}

function showPluginInfo(descr) {
	var info		= document.getElementById('pluginInfo');
	var content	= document.getElementById('pluginInfoContent');
	info.style.display	= 'block';
	content.innerHTML		= descr;
}

function hidePluginInfo() {
	var info		= document.getElementById('pluginInfo');
	var content	= document.getElementById('pluginInfoContent');
	info.style.display	= 'none';
	content.innerHTML		= '';
}

function startDrag(objElem) {
	objDrag	= objElem;
	offX		= mouseX - objDrag.offsetLeft;
	offY		= mouseY - objDrag.offsetTop;
}

function doDrag(ereignis) {
	mouseX = (IE) ? window.event.clientX : ereignis.pageX;
	mouseY = (IE) ? window.event.clientY : ereignis.pageY;

	if (objDrag != null) {
		objDrag.style.left	= (mouseX - offX) + "px";
		objDrag.style.top		= (mouseY - offY) + "px";
	}
}

function stopDrag(ereignis) {
	objDrag = null;
}

function showFloatingPopup(_header, _content) {
	var popup		= document.getElementById('floatingPopup');
	var header	= document.getElementById('floatingPopupHeader');
	var content	= document.getElementById('floatingPopupContent');
	popup.style.display	= 'block';
	header.innerHTML		= _header;
	content.innerHTML		= _content;
}

function hideFloatingPopup() {
	var popup		= document.getElementById('floatingPopup');
	var header	= document.getElementById('floatingPopupHeader');
	var content	= document.getElementById('floatingPopupContent');
	popup.style.display	= 'none';
	header.innerHTML		= '';
	content.innerHTML		= '';
}

function clearTextfield(id) {
	var jumpto					= document.getElementById(id);
	jumpto.value				= '';
	jumpto.style.color	= '#000000'
}
