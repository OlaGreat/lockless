/** A file from `public/`, addressed under the path the app is served from (e.g. GitHub Pages). */
export function publicAsset(path: string, base: string = import.meta.env.BASE_URL): string {
  return `${base}${path.replace(/^\//, "")}`;
}
