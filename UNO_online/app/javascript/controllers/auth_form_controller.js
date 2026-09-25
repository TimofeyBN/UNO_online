import { Controller } from "@hotwired/stimulus";

// Клиентская валидация формы логина/регистрации — быстрая обратная связь
// до отправки на сервер. Финальная проверка всё равно выполняется в Rails
// (модель User), это только UX-слой.
export default class extends Controller {
  static targets = ["name", "email", "password", "submit"];
  static values = { mode: String }; // "login" | "register"

  connect() {
    this.clearErrors();
  }

  validate(event) {
    const errors = {};

    if (this.modeValue === "register" && this.hasNameTarget && !this.nameTarget.value.trim()) {
      errors.name = "Введите имя";
    }

    const email = this.emailTarget.value.trim();
    if (!email) {
      errors.email = "Введите email";
    } else if (!/^\S+@\S+\.\S+$/.test(email)) {
      errors.email = "Некорректный email";
    }

    const password = this.passwordTarget.value;
    if (!password) {
      errors.password = "Введите пароль";
    } else if (password.length < 6) {
      errors.password = "Минимум 6 символов";
    }

    this.renderErrors(errors);

    if (Object.keys(errors).length > 0) {
      event.preventDefault();
    }
  }

  clearErrors() {
    this.renderErrors({});
  }

  renderErrors(errors) {
    for (const target of ["name", "email", "password"]) {
      const hasTarget = this[`has${capitalize(target)}Target`];
      if (!hasTarget) continue;

      const input = this[`${target}Target`];
      const errorEl = input.closest(".field")?.querySelector(".field__error");
      const message = errors[target];

      input.classList.toggle("field__input--error", Boolean(message));
      if (errorEl) errorEl.textContent = message || "";
    }
  }
}

function capitalize(word) {
  return word.charAt(0).toUpperCase() + word.slice(1);
}
