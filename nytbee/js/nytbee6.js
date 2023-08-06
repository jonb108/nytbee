var lets;
var nw;
var hnw;
var main;
function init() {
    nw   = document.getElementById('new_words');
    hnw  = document.getElementById('hidden_new_words');
    lets = document.getElementById('lets');
    main = document.getElementById('main');
}
function empty(s) {
    return s.trim().length === 0;
}
function add_let(c) {
    lets.innerHTML += c;
}
function add_redlet(c) {
    lets.innerHTML += '<span class=red>' + c + '</span>';
}
// hello => hell
// hell<span class="red">o</span> => hell
function del_let() {
    var s = lets.innerHTML;
    var l = s.length;
    if (s.substring(l-1) == '>') {
        s = s.substring(0, l-26);
    }
    else {
        s = s.substring(0, l-1);
    }
    lets.innerHTML = s;
}
function issue_cmd(s) {
    hnw.value = s;
    main.submit();
}
function stash_lets() {
    hnw.value = 'SW ' + lets.textContent;
    main.submit();
}
function sub_lets() {
    hnw.value = lets.textContent;
    main.submit();
}
function check_name_location() {
    var name = document.getElementById('name');
    if (empty(name.value)) {
        alert('Please provide a Name.');
        name.focus();
        return false;
    }
    var location = document.getElementById('location');
    if (empty(location.value)) {
        alert('Please provide a Location.');
        location.focus();
        return false;
    }
    return true;
}
function add_clues() {
    set_focus();
    document.getElementById('add_clues').submit();
}
function clues_by(person_id) {
    document.getElementById('person_id').value = person_id;
    document.getElementById('clues_by').submit();
    set_focus();
}
function set_focus() {
    setTimeout(() => { window.scrollTo(0, 0); }, 20);
    nw.focus();
    return true;
}
// for obscuring my email address
function xyz(s) {
    var out = '';
    for (let i = 0; i < s.length; ++i) {
        out += String.fromCharCode(s.charCodeAt(i)-1);
    }
    return out;
}
function abcd(efg) {
    document.write(xyz('=b!isfg>(nbjmup;Kpo!Ckpsotube!=kpo/ckpsotubeAhnbjm/dpn?@tvckfdu>OZU!Cff(?'));
    document.write(efg + "</a>");
}
function copy_uuid_to_clipboard(uuid) {
    navigator.clipboard.writeText(uuid);
    show_copied('uuid');
}
function show_copied(id) {
    var el = document.getElementById(id);
    el.innerHTML = 'copied';
    setTimeout(() => {
        el.innerHTML = "";
    }, 1000);
}
function full_def(word) {
    window.open('https://wordnik.com/words/' + word,
                'wordnik', 'width=1000');
    set_focus();
}
function popup_define(word, height, width) {
    newwin = window.open(
        "https://logicalpoetry.com/cgi-bin/nytbee_define.pl/"
            + word, 'define',
        'height=' + height + ',width=' + width +', scrollbars'
    );
    newwin.moveTo(800, 0);
    document.getElementById(word + '_clue').focus();
}
function del_post(id) {
    document.getElementById('x' + id).style.pointerEvents = "none";
    if (confirm('Deleting your post. Are you sure?')) {
        hnw.value = 'FX' + id;
        main.submit();
    }
}
function edit_post(id) {
    document.getElementById('e' + id).style.pointerEvents = "none";
    hnw.value = 'FE' + id;
    main.submit();
}
