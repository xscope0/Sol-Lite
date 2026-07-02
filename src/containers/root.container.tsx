import clsx from 'clsx'
import {observer} from 'mobx-react-lite'
import {Text, TouchableOpacity, View} from 'react-native'
import {useStore} from 'store'
import {Widget} from 'stores/ui.store'
import {CreateItemWidget} from 'widgets/createItem.widget'
import {FileSearchWidget} from 'widgets/fileSearch.widget'
import {OnboardingWidget} from 'widgets/onboarding.widget'
import {ProcessesWidget} from 'widgets/processes.widget'
import {SearchWidget} from 'widgets/search.widget'
import {SettingsWidget} from 'widgets/settings.widget'

export const RootContainer = observer(() => {
  const store = useStore()
  const widget = store.ui.focusedWidget

  let subWindow = (
    <View
      className={clsx('dark:bg-gray-900/10', {
        fullWindow: !!store.ui.query,
      })}>
      <SearchWidget />
    </View>
  )

  if (widget === Widget.FILE_SEARCH) {
    subWindow = (
      <View className="fullWindow">
        <FileSearchWidget />
      </View>
    )
  }

  if (widget === Widget.CREATE_ITEM) {
    subWindow = (
      <View className="fullWindow">
        <CreateItemWidget />
      </View>
    )
  }

  if (widget === Widget.ONBOARDING) {
    subWindow = (
      <View className="fullWindow">
        <OnboardingWidget />
      </View>
    )
  }


  if (widget === Widget.SETTINGS) {
    subWindow = (
      <View className="fullWindow">
        <SettingsWidget />
      </View>
    )
  }

  if (widget === Widget.PROCESSES) {
    subWindow = (
      <View className="fullWindow">
        <ProcessesWidget />
      </View>
    )
  }

  return (
    <View>
      <View onLayout={store.ui.setWindowHeight}>{subWindow}</View>
      {store.ui.confirmDialogShown && (
        <View className="absolute bottom-0 top-0 left-0 right-0 bg-black/50 items-center justify-center">
          <View className="bg-white dark:bg-neutral-800 p-6 gap-1 rounded-xl border border-color">
            <Text className="text font-semibold">{store.ui.confirmTitle}</Text>
            <Text className="text mb-2">Are you sure you want to proceed?</Text>
            <TouchableOpacity
              onPress={() => {
                store.ui.executeConfirmCallback()
              }}>
              <View className="rounded-full bg-accent-strong w-full p-2 items-center justify-center">
                <Text className="text-white">Proceed</Text>
              </View>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => {
                store.ui.closeConfirm()
              }}>
              <View className="rounded-full w-full p-2 bg-neutral-200 dark:bg-neutral-600 items-center justify-center">
                <Text>Cancel</Text>
              </View>
            </TouchableOpacity>
          </View>
        </View>
      )}
    </View>
  )
})
