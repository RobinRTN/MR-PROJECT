import { Controller } from "@hotwired/stimulus";

export default class extends Controller {

  connect() {
    console.log("COOONNNNEEECCTTTEDD")
  }
  removeRecord(event) {
    console.log("SSUPPPRRR")
    event.preventDefault();
    event.target.previousElementSibling.value = '1';
    console.log(event.target.previousElementSibling)
    event.target.closest('.formule-fields').style.display = 'none';
    
  }

  addFields(event) {
    console.log("Add Fields Triggered")
    event.preventDefault();
    let time = new Date().getTime();
    let regexp = new RegExp(event.target.dataset.id, 'g');
    let newFields = event.target.dataset.fields.replace(regexp, time);
    let insertionPosition = (window.location.pathname === "/users/edit_formules") ? 'afterbegin' : 'beforeend';
    this.element.querySelector('.fields').insertAdjacentHTML(insertionPosition, newFields);
  }
}
