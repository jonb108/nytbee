function empty(s) {
    return s.trim().length === 0;
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
