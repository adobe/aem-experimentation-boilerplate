/**
 * Configuration for experimentation.
 * @type {Object}
 */
const experimentationConfig = {
  prodHost: 'www.my-site.com',
  audiences: {
    mobile: () => window.innerWidth < 600,
    desktop: () => window.innerWidth >= 600,
    // define your custom audiences here as needed
  },
};

/**
 * Checks if experimentation is enabled.
 * @returns {boolean} True if experimentation is enabled, false otherwise.
 */
const isExperimentationEnabled = () => document.head.querySelector('[name^="experiment"],[name^="campaign-"],[name^="audience-"],[property^="campaign:"],[property^="audience:"]')
|| [...document.querySelectorAll('.section-metadata div')].some((d) => d.textContent.match(/Experiment|Campaign|Audience/i));
[...document.querySelectorAll('.section-metadata div')].some((d) => d.textContent.match(/Experiment|Campaign|Audience/i));

/**
 * Loads the experimentation module (eager).
 * @param {Document} document The document object.
 * @returns {Promise<void>} A promise that resolves when the experimentation module is loaded.
 */
export async function loadExperimentationEager(document) {
  if (!isExperimentationEnabled()) {
    return null;
  }

  try {
    const { loadEager } = await import(
      '../plugins/experimentation/src/index.js'
    );
    return loadEager(document, experimentationConfig);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to load experimentation module (eager):', error);
    return null;
  }
}

/**
 * Loads the experimentation module (lazy).
 * @param {Document} document The document object.
 * @returns {Promise<void>} A promise that resolves when the experimentation module is loaded.
 */
export async function loadExperimentationLazy(document) {
  if (!isExperimentationEnabled()) {
    return null;
  }

  try {
    const { loadLazy } = await import(
      '../plugins/experimentation/src/index.js'
    );
    await loadLazy(document, experimentationConfig);

    const loadSidekickHandler = () => import('../tools/sidekick/aem-experimentation.js');

    if (document.querySelector('helix-sidekick, aem-sidekick')) {
      await loadSidekickHandler();
    } else {
      await new Promise((resolve) => {
        document.addEventListener(
          'sidekick-ready',
          () => {
            loadSidekickHandler().then(resolve);
          },
          { once: true },
        );
      });
    }

    return true;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to load experimentation module (lazy):', error);
    return null;
  }
}
