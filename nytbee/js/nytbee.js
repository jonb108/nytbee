function empty(s) {
    return s.trim().length === 0;
}
function add_let(c) {
    document.getElementById('new_words').value += c;
}
function del_let() {
    var el = document.getElementById('new_words');
    var s = el.value;
    el.value = s.slice(0, -1);
}
function shuffle() {
    document.getElementById('new_words').value = '';
    document.getElementById('main').submit();
}
function sub_lets() {
    document.getElementById('main').submit();
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
function new_date(d) {
    document.getElementById('new_words').value = d;
    document.getElementById('main').submit();
}
function add_clues() {
    set_focus();
    document.getElementById('add_clues').submit();
}
function define_tl(two_let) {
    document.getElementById('new_words').value = 'D' + two_let;
    document.getElementById('main').submit();
}
function define_ht(c, n) {
    document.getElementById('new_words').value = 'D' + c + n;
    document.getElementById('main').submit();
}
function clues_by(person_id) {
    document.getElementById('person_id').value = person_id;
    document.getElementById('clues_by').submit();
    set_focus();
}
function set_focus() {
    document.form.new_words.focus();
    return true;
}
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
