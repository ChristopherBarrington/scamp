
const tour = new Shepherd.Tour({
  useModalOverlay: true,
  defaultStepOptions: {
    classes: '',
    scrollTo: true,
    exitOnEsc: true,
    cancelIcon: {enabled: true},
    modalOverlayOpeningRadius: 5,
    arrow: false
  }
});

console.log(steps)

for (let [id, params] of steps) {
	tour.addStep({
	  id: id,
	  text: params.text,
	  title: null,
	  attachTo: { element: document.getElementById(params.target), on: 'left' },
	  buttons: [
	    { text: 'Previous', action: tour.back },
	    { text: 'Next', action: tour.next }
	  ],
	});
}
