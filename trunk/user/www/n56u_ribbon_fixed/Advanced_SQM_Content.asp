<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#menu5_14_1#></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/itoggle.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>

<script>
var $j = jQuery.noConflict();

// Danh sách interface đọc từ NVRAM qua ASP
var wan_ifname  = "<% nvram_get_x("","wan_ifname"); %>";   // vd: eth3
var ppp_ifname  = "<% nvram_get_x("","wan_pppoe_ifname"); %>"; // vd: ppp0
var saved_iface = "<% nvram_get_x("","sqm_interface"); %>";

$j(document).ready(function() {
    init_itoggle('sqm_enabled', change_sqm_enabled);
    build_iface_dropdown();
    change_sqm_enabled();
});

function build_iface_dropdown() {
    var sel = document.getElementById("sqm_interface_sel");
    sel.options.length = 0;

    var ifaces = [];

    // PPPoE ưu tiên đầu
    if (ppp_ifname && ppp_ifname !== "") ifaces.push(ppp_ifname);

    // WAN DHCP
    if (wan_ifname && wan_ifname !== "" && ifaces.indexOf(wan_ifname) < 0)
        ifaces.push(wan_ifname);

    // Repeater mode - apclii0 (5GHz) và apcli0 (2.4GHz)
    // Đây là WAN thực tế khi router ở chế độ repeater
    var extras = ["apclii0", "apcli0", "eth3", "eth2.2", "br0"];
    for (var i = 0; i < extras.length; i++) {
        if (ifaces.indexOf(extras[i]) < 0)
            ifaces.push(extras[i]);
    }

    for (var i = 0; i < ifaces.length; i++) {
        var opt = document.createElement("option");
        opt.value = ifaces[i];

        // Thêm label mô tả
        var label = ifaces[i];
        if (ifaces[i] === "apclii0") label = "apclii0 (WiFi 5GHz repeater)";
        if (ifaces[i] === "apcli0")  label = "apcli0 (WiFi 2.4GHz repeater)";
        if (ifaces[i] === "ppp0")    label = "ppp0 (PPPoE WAN)";
        if (ifaces[i] === "eth3")    label = "eth3 (DHCP WAN)";

        opt.text = label;
        if (ifaces[i] === saved_iface) opt.selected = true;
        sel.appendChild(opt);
    }

    // Nếu saved_iface không có trong list thì thêm vào
    if (saved_iface !== "") {
        var found = false;
        for (var i = 0; i < sel.options.length; i++) {
            if (sel.options[i].value === saved_iface) { found = true; break; }
        }
        if (!found) {
            var opt = document.createElement("option");
            opt.value = saved_iface;
            opt.text  = saved_iface + " (current)";
            opt.selected = true;
            sel.appendChild(opt);
        }
    }
}

function change_sqm_enabled() {
    var v = document.form.sqm_enabled[1].value;
    var v = (enabled == "1");
    showhide_div("sqm_download_speed", v);
    showhide_div("sqm_upload_speed", v);
    showhide_div("sqm_interface_row", v);
}

function applyRule() {
    if (validForm()) {
        // Đồng bộ giá trị từ dropdown → hidden input trước khi submit
        var sel = document.getElementById("sqm_interface_sel");
        document.form.sqm_interface.value = sel.options[sel.selectedIndex].value;

        showLoading();
        document.form.action_mode.value   = " Apply ";
        document.form.current_page.value  = "/Advanced_SQM_Content.asp";
        document.form.next_page.value     = "";
        document.form.submit();
    }
}

function done_validating(action) {
    refreshpage();
}

function validForm() {
    if (document.form.sqm_enabled.value == "0") return true;

    var ul  = parseInt(document.form.sqm_upload_speed.value, 10);
    var dl  = parseInt(document.form.sqm_download_speed.value, 10);
    var sel = document.getElementById("sqm_interface_sel");

    if (!sel || sel.selectedIndex < 0) {
        alert("Please select a network interface.");
        return false;
    }
    if (isNaN(ul) || isNaN(dl) || ul <= 0 || dl <= 0) {
        alert("Please enter valid positive integers for upload and download speed.");
        return false;
    }
    return true;
}
</script>

<script>
<% login_state_hook(); %>

function initial() {
    show_banner(1);
    show_menu(5,13,1);
    show_footer();
}
</script>
</head>

<body onload="initial();" onunLoad="return unload_body();">
<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9"><div id="TopBanner"></div></div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>
    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
    <input type="hidden" name="current_page"  value="Advanced_SQM_Content.asp">
    <input type="hidden" name="next_page"     value="">
    <input type="hidden" name="next_host"     value="">
    <input type="hidden" name="sid_list"      value="ExtraApplications;">
    <input type="hidden" name="group_id"      value="">
    <input type="hidden" name="action_mode"   value="">
    <input type="hidden" name="action_script" value="">

    <!-- Hidden input — nhận giá trị từ dropdown trước khi submit -->
    <input type="hidden" name="sqm_interface" value="<% nvram_get_x("","sqm_interface"); %>">

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li><div id="subMenu" class="accordion"></div></li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_14_1#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <div class="alert alert-info" style="margin:10px;">
                                        <#SQM_Desc#>
                                    </div>

                                    <table width="100%" align="center" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th colspan="4" style="background-color:#E3E3E3;">Status</th>
                                        </tr>

                                        <!-- Toggle bật/tắt -->
                                        <tr>
                                            <th width="50%"><#SQM_Toggle#></th>
                                            <td>
                                                <div class="main_itoggle">
                                                    <div id="sqm_enabled_on_of">
                                                        <input type="checkbox" id="sqm_enabled_fake"
                                                            <% nvram_match_x("","sqm_enabled","1","value=1 checked"); %>
                                                            <% nvram_match_x("","sqm_enabled","0","value=0"); %>>
                                                    </div>
                                                </div>
                                                <div style="position:absolute;margin-left:-10000px;">
                                                    <input type="radio" value="1" name="sqm_enabled" id="sqm_enabled_1"
                                                        onclick="change_sqm_enabled();"
                                                        <% nvram_match_x("","sqm_enabled","1","checked"); %>><#checkbox_Yes#>
                                                    <input type="radio" value="0" name="sqm_enabled" id="sqm_enabled_0"
                                                        onclick="change_sqm_enabled();"
                                                        <% nvram_match_x("","sqm_enabled","0","checked"); %>><#checkbox_No#>
                                                </div>
                                            </td>
                                        </tr>

                                        <!-- Dropdown interface -->
                                        <tr id="sqm_interface_row">
                                            <th width="50%"><#SQM_If#></th>
                                            <td>
                                                <select id="sqm_interface_sel" class="input" style="width:200px;">
                                                    <!-- Được điền động bởi build_iface_dropdown() -->
                                                </select>
                                                <span style="color:#888;font-size:11px;">
                                                    &nbsp;WAN: <% nvram_get_x("","wan_ifname"); %>
                                                    &nbsp;PPP: <% nvram_get_x("","wan_pppoe_ifname"); %>
                                                </span>
                                            </td>
                                        </tr>

                                        <!-- Download speed -->
                                        <tr id="sqm_download_speed">
                                            <th width="50%"><#SQM_DL#> (kbps)</th>
                                            <td>
                                                <input type="text" maxlength="10" class="input" size="15"
                                                    name="sqm_download_speed"
                                                    value="<% nvram_get_x("","sqm_download_speed"); %>" />
                                            </td>
                                        </tr>

                                        <!-- Upload speed -->
                                        <tr id="sqm_upload_speed">
                                            <th width="50%"><#SQM_UL#> (kbps)</th>
                                            <td>
                                                <input type="text" maxlength="10" class="input" size="15"
                                                    name="sqm_upload_speed"
                                                    value="<% nvram_get_x("","sqm_upload_speed"); %>" />
                                            </td>
                                        </tr>

                                        <tr>
                                            <td colspan="4" style="border-top:0 none;">
                                                <br/>
                                                <center>
                                                    <input class="btn btn-primary" style="width:219px"
                                                        type="button" value="<#CTL_apply#>"
                                                        onclick="applyRule()" />
                                                </center>
                                            </td>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    </form>

    <div id="footer"></div>
</div>
</body>
</html>
