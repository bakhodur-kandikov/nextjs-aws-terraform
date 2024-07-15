import { PlanetsSlideShow } from "../components/PlanetsSlideShow";

export default function Home() {
  return (
    <div className="h-full w-full bg-white">
      <div className="h-full flex items-center justify-center">
        <div className="flex-2">
          <PlanetsSlideShow />
        </div>
      </div>
    </div>
  );
}

