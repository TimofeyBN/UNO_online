import { Controller } from "@hotwired/stimulus";

// Пока нет ActionCable — опрашиваем сервер перезагрузкой страницы,
// чтобы увидеть изменения статуса "готов" у других игроков.
// В отличие от <meta http-equiv="refresh">, таймер здесь правильно
// отменяется через disconnect(), когда Turbo уводит со страницы —
// поэтому переход в меню больше не утаскивает обратно в лобби.
export default class extends Controller {
  static values = { interval: { type: Number, default: 3000 } };

  connect() {
    this.timeout = setTimeout(() => {
      window.location.reload();
    }, this.intervalValue);
  }

  disconnect() {
    clearTimeout(this.timeout);
  }
}
