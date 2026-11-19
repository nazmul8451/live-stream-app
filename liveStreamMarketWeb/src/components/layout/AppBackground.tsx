/**
 * The app's backdrop: a near-black canvas with three soft colour blooms.
 *
 * This is the web reading of `CustomBackground` in the Flutter app — same base
 * (#02010A) and same three bloom colours, placed so the page keeps the app's
 * depth without a screenshot-perfect copy of positions that were laid out for
 * a 390pt phone. The blooms are fixed rather than scrolled so long pages do
 * not drag a gradient down with them.
 */
export function AppBackground() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-canvas"
    >
      {/* Magenta, upper left */}
      <div className="absolute -left-[20%] -top-[10%] h-[55vh] w-[70vw] rounded-full bg-bloom-magenta/50 blur-[120px] sm:h-[60vh] sm:w-[45vw]" />
      {/* Blue, lower right */}
      <div className="absolute -right-[15%] top-[35%] h-[60vh] w-[70vw] rounded-full bg-bloom-blue/60 blur-[130px] sm:w-[50vw]" />
      {/* Violet, centre, the faintest of the three */}
      <div className="absolute left-[10%] top-[60%] h-[50vh] w-[60vw] rounded-full bg-bloom-violet/30 blur-[120px] sm:w-[40vw]" />
    </div>
  );
}
