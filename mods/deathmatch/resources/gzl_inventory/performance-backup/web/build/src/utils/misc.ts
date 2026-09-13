// Will return whether the current environment is in a regular browser
// and not CEF
export const isEnvBrowser = (): boolean =>
  !(window as any).invokeNative && !(window as any).mta && !(window as any).GetParentResourceName && !window.location.href.includes('mta');

// Basic no operation function
export const noop = () => {};

