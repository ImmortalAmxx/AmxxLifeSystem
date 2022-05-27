# Информация

Добавляет на Ваш сервер плагин систему жизней. При убийстве игроку дается жизнь, так же ее можно купить или продать в меню. Все настройки происходят в конфиге. Конфиг создается автоматически. Путь к конфигу addons/amxmodx/configs/plugins/AmxxLifes.cfg

## Требования
```c
AmxModX 1.9.0 + ReAPI 5.21.0.252
```
## Нативы
```python
amxx_get_user_lifes(iIndex);
amxx_set_user_life(iIndex, iNum);
```
## Установка

```python
Переместить папку data по пути addons/amxmodx/
Скомпилировать AmxxLifes.sma (Используйте компилятор 1.9.0)
Переместить плагин в папку plugins
Прописать в plugins.ini строчку AmxxLifes.amxx
```# AmxxLifeSystem
