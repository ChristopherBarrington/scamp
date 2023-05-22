---
title: shepherd

headingPre: |
  <script src="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/js/shepherd.min.js"></script>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/shepherd.js@10.0.1/dist/css/shepherd.css"/>
---

{{% button style="primary" icon="bullhorn" href="javascript:tour.start();" %}}Start the tour{{% /button %}}

{{< highlight yaml "linenos=inline,anchorlinenos=true,lineanchors=vicky" >}}
title: "Signac"
tags:
  - R
  - bash
  - Mac OS X
{{< /highlight >}}


<script>

const tour = new Shepherd.Tour({
  useModalOverlay: true,
  defaultStepOptions: {
    classes: 'shadow-md bg-purple-dark',
    scrollTo: true,
    exitOnEsc: true
  }
});

tour.addStep({
  id: 'example-step',
  text: 'This step is attached to the bottom of the <code>.example-css-selector</code> element.',
  attachTo: {
    element: document.getElementById("vicky-1"),
    on: 'left'
  },
  buttons: [
    {
      text: 'Next',
      action: tour.next
    }
  ],
  title: "The first step"
});

tour.addStep({
  id: 'example-step2',
  text: 'This step is attached to the bottom of the <code>.example-css-selector</code> element.',
  attachTo: {
    element: document.getElementById("vicky-2"),
    on: 'left'
  },
  buttons: [
    {
      text: 'Next',
      action: tour.next
    }
  ],
  title: "The second step"
});


tour.addStep({
  id: 'shortcuts',
  text: 'This step is attached to the bottom of the <code>.example-css-selector</code> element.',
  attachTo: {
    element: document.getElementById("vicky-3"),
    on: 'left'
  },
  buttons: [
    {
      text: 'Next',
      action: tour.next
    }
  ]
});
</script>