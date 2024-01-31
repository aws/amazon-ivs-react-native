import fs from 'fs';
import path from 'path';
import semver from 'semver';
import inquirer from 'inquirer';
import { simpleGit } from 'simple-git';
import pkg from '../package.json';
import { logError, logInfo } from './utils';

async function run() {
  const skipChecks = !!process.env.SKIP_CHECKS;
  const git = simpleGit();
  const status = await git.status();

  if (!skipChecks) {
    if (status.current !== 'main') {
      return logError('Must be on main branch to create a release branch');
    }

    if (!status.isClean()) {
      return logError('Cannot create release with dirty working tree');
    }

    if (status.ahead > 0) {
      return logError(
        `Local commits on main must match with origin/main. You are ${status.ahead} commit(s) ahead`
      );
    }

    if (status.behind > 0) {
      return logError(
        `Local commits on main must match with origin/main. You are ${status.behind} commit(s) behind`
      );
    }
  }

  try {
    // different behavior based on rc version or not
    const prerelease = (semver.prerelease(pkg.version) ?? []).length;

    let bumps = prerelease
      ? ['prereleasenext', 'prereleasepatch', 'prereleasedone']
      : ['premajor', 'preminor', 'prepatch', 'major', 'minor', 'patch'];

    const versions = bumps.map((type) => {
      let version: string | null = pkg.version;
      if (version) {
        const prereleasepatch = prerelease > 2;
        switch (type) {
          case 'prereleasenext':
            version = semver.inc(
              prereleasepatch ? version.replace(/\.[^.]*$/gm, '') : version,
              'prerelease',
              'rc',
              '1'
            );
            break;
          case 'prereleasepatch':
            version = prereleasepatch
              ? semver.inc(version, 'prerelease', 'rc', '1')
              : `${version}.2`;
            break;
          case 'prereleasedone':
            version = version.replace(/-rc.*/gm, '');
            break;
          case 'premajor':
          case 'preminor':
          case 'prepatch':
          case 'prerelease':
            version = semver.inc(
              version,
              type as semver.ReleaseType,
              'rc',
              '1'
            );
            break;
          default:
            version = semver.inc(version, type as semver.ReleaseType);
            break;
        }
        if (!version) {
          throw new Error(`Invalid version: ${version}`);
        }
      }
      return { name: `${type} ${version}`, value: version };
    });

    const answers = await inquirer.prompt([
      {
        type: 'list',
        name: 'bump',
        message: `${pkg.version}: select release type`,
        default: versions[1].value,
        choices: versions,
      },
    ]);

    // update to new version
    pkg.version = answers.bump;

    // create release branch
    const branchName = `release/${pkg.version}`;
    await git.checkoutLocalBranch(branchName);

    // write package.json version change
    const pkgFilePath = path.join(__dirname, '../package.json');
    fs.writeFileSync(pkgFilePath, `${JSON.stringify(pkg, null, '  ')}\n`);

    // write example xcode project version change
    const projectFilePath = path.join(
      __dirname,
      '../example/ios/AmazonIvsExample.xcodeproj/project.pbxproj'
    );
    const projectFile = fs.readFileSync(projectFilePath, { encoding: 'utf8' });

    const updatedProjectFile = projectFile.replaceAll(
      /MARKETING_VERSION = [\d.]+;/g,
      `MARKETING_VERSION = ${pkg.version};`
    );

    fs.writeFileSync(projectFilePath, updatedProjectFile);

    // commit version change(s)
    const message = `created ${branchName} branch`;
    await git
      .add(pkgFilePath)
      .add(projectFilePath)
      .commit(`chore: ${message}`, { '--no-verify': null });

    logInfo(message);
    logInfo(`don't forget to git push -u origin ${branchName}`);
  } catch (err) {
    console.error(err);
  }
}

run();
