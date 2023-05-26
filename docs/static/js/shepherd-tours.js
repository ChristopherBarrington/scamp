
// define a generic shepherd tour
function make_default_tour(steps_json) {
	const tour = new Shepherd.Tour({
		useModalOverlay: true,
		defaultStepOptions: {
			classes: '',
			scrollTo: true,
			exitOnEsc: true,
			cancelIcon: {
				enabled: true },
			modalOverlayOpeningRadius: 4,
			arrow: false }});

	const steps = new Map(Object.entries(steps_json));
	const buttons = [{text: 'Previous', action: tour.back},
	                 {text: 'Next', action: tour.next},
	                 {text: 'Exit', action: tour.cancel}];
	let tour_steps = new Array;

	for (let [id, params] of steps) {
		const s = new Shepherd.Step(tour, {
			id: id,
			text: params.text,
			title: params.title,
			attachTo: {
				element: document.getElementById(params.target),
				on: params.position || 'left' },
			buttons: tour_steps.length == 0 ? [buttons[1]] : [buttons[0], buttons[1]] });
		tour_steps.push(s);
	}

	tour.addSteps(tour_steps);
	return tour;
}
