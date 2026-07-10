(function () {
  function isAuxiliarySubmit(submitter) {
    if (!submitter) {
      return false;
    }
    return (
      submitter.name === 'band_list_refresh' ||
      submitter.name === 'dropbox_disconnect' ||
      Boolean(submitter.getAttribute('formaction'))
    );
  }

  function setBusyLabel(button, busyLabel) {
    if (button.tagName === 'INPUT') {
      if (!button.dataset.prevValue) {
        button.dataset.prevValue = button.value;
      }
      button.value = busyLabel;
      return;
    }
    if (!button.dataset.prevLabel) {
      button.dataset.prevLabel = button.textContent;
    }
    button.textContent = busyLabel;
  }

  function clearBusyState() {
    document.querySelectorAll('form.form-is-submitting').forEach((form) => {
      form.classList.remove('form-is-submitting');
    });
    document.querySelectorAll('.form-busy-hint').forEach((hint) => {
      hint.remove();
    });
    document.querySelectorAll('button[type="submit"], input[type="submit"]').forEach((btn) => {
      btn.disabled = false;
      if (btn.tagName === 'INPUT' && btn.dataset.prevValue) {
        btn.value = btn.dataset.prevValue;
      } else if (btn.dataset.prevLabel) {
        btn.textContent = btn.dataset.prevLabel;
      }
    });
  }

  document.body.addEventListener(
    'submit',
    function (event) {
      const form = event.target;
      if (!(form instanceof HTMLFormElement)) {
        return;
      }

      const submitter = event.submitter;
      if (isAuxiliarySubmit(submitter)) {
        return;
      }

      const busyLabel =
        submitter && submitter.classList.contains('secondary') ? 'Working…' : 'Saving…';

      form.classList.add('form-is-submitting');

      if (submitter) {
        submitter.classList.add('is-busy');
        setBusyLabel(submitter, busyLabel);
      }

      if (!form.querySelector('.form-busy-hint')) {
        const hint = document.createElement('p');
        hint.className = 'hint loading form-busy-hint';
        hint.setAttribute('role', 'status');
        hint.setAttribute('aria-live', 'polite');
        hint.textContent = busyLabel + ' Please wait…';

        const actionRow = form.querySelector('.config-actions, .form-row:last-of-type .form-input');
        if (actionRow) {
          actionRow.appendChild(hint);
        } else {
          form.appendChild(hint);
        }
      }
    },
    true
  );

  window.addEventListener('pageshow', function (event) {
    if (event.persisted) {
      clearBusyState();
    }
  });
})();
